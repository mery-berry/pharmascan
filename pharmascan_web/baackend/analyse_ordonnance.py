import google.generativeai as genai  # type: ignore
import json
import pandas as pd  # type: ignore
from PIL import Image  # type: ignore
import os
import re
import unicodedata
from itertools import combinations
from collections import defaultdict
from typing import Any, Dict, List, Optional

# NOTE: In production, don't hardcode API keys — use environment variables.
API_KEY = os.getenv("GENAI_API_KEY", "AIzaSyDnPanBs0_h9QXbrBjAL-dZlMovVR5O1QM")
genai.configure(api_key=API_KEY)
model = genai.GenerativeModel("gemini-2.5-flash")

# Default data file paths (adjust to your environment)
DCI_DB_PATH = "base_medicaments.xls"
THESAURUS_EXCEL_PATH = "thesaurus_interactions.xlsx"
FAMILLES_MAPPING_PATH = "familles_thesaurus.xlsx"
CONSEILS_PATH = "conseils_ordonnances.xlsx"

# -----------------
# Utilities
# -----------------

def normalize(s: Optional[str]) -> str:
    if s is None:
        return ""
    s2 = str(s)
    s2 = unicodedata.normalize("NFD", s2)
    s2 = "".join(ch for ch in s2 if unicodedata.category(ch) != "Mn")
    return s2.lower().strip()


def deduplicate_interactions(results: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    seen = set()
    deduped: List[Dict[str, Any]] = []
    for r in results:
        a = normalize(r.get("A"))
        b = normalize(r.get("B"))
        key = tuple(sorted([a, b])) + (r.get("Gravity"), normalize(r.get("Details", ""))[:80])
        if key not in seen:
            seen.add(key)
            deduped.append(r)
    return deduped


# -----------------
# Data loaders
# -----------------

def load_dci_db(path: str) -> Dict[str, str]:
    if not os.path.exists(path):
        raise FileNotFoundError(f"DCI database file not found: {path}")
    df = pd.read_excel(path)
    df["nomcommercial_norm"] = df["nomcommercial"].astype(str).apply(normalize)
    return dict(zip(df["nomcommercial_norm"], df["dci"]))


def load_interactions_from_excel(path: str) -> List[Dict[str, Any]]:
    if not os.path.exists(path):
        raise FileNotFoundError(f"Fichier introuvable : {path}")
    df = pd.read_excel(path)
    interactions: List[Dict[str, Any]] = []
    for _, row in df.iterrows():
        interactions.append(
            {
                "A": str(row["Medicament_A"]).strip(),
                "B": str(row["Medicament_B"]).strip(),
                "Gravity": str(row["Gravite"]).strip() if pd.notna(row.get("Gravite")) else None,
                "Details": str(row.get("Details_Conseils", "")).strip() if pd.notna(row.get("Details_Conseils")) else "",
                "Page": int(row["Page"]) if pd.notna(row.get("Page")) else None,
                "Mecanisme": str(row.get("Mecanisme", "")).strip() if pd.notna(row.get("Mecanisme")) else "",
            }
        )
    return interactions


def load_conseils(path: str) -> List[Dict[str, Any]]:
    if not os.path.exists(path):
        return []
    df = pd.read_excel(path)
    conseils: List[Dict[str, Any]] = []
    for _, row in df.iterrows():
        conseils.append(
            {
                "dci": normalize(str(row.get("dci", ""))),
                "voie": normalize(str(row.get("voie", ""))),
                "forme": normalize(str(row.get("Forme_galénique", ""))),
                "type_conseil": str(row.get("Type_conseil", "")),
                "texte": str(row.get("Texte", "")),
            }
        )
    return conseils


def load_familles(path: str) -> Dict[str, set]:
    if not os.path.exists(path):
        return {}
    if path.lower().endswith((".xls", ".xlsx")):
        df = pd.read_excel(path)
    else:
        df = pd.read_csv(path, encoding="utf-8-sig")
    col_fam, col_dcis = df.columns[0], df.columns[1]
    fam_map: Dict[str, set] = {}
    for _, row in df.iterrows():
        fam = normalize(str(row[col_fam]))
        dcis_raw = str(row[col_dcis])
        parts = [p.strip() for p in re.split(r"[;,]", dcis_raw) if p.strip()]
        dcis = set(normalize(p) for p in parts)
        fam_map[fam] = dcis
    return fam_map


def build_reverse_map(fam_map: Dict[str, set]) -> Dict[str, set]:
    rev: Dict[str, set] = defaultdict(set)
    for fam, dcis in fam_map.items():
        for d in dcis:
            rev[d].add(fam)
    return rev


def canonical_family_key(entry: str, fam_map: Dict[str, set]) -> Optional[str]:
    s = normalize(entry)
    s_no_paren = re.sub(r"\(.*?\)", "", s).strip()
    if s in fam_map:
        return s
    if s_no_paren in fam_map:
        return s_no_paren
    return None


def expand_patient_strict(meds: List[str], rev_map: Dict[str, set]):
    meds_set = {normalize(m) for m in meds}
    fams_set = set()
    for m in meds_set:
        fams_set |= rev_map.get(m, set())
    return meds_set, fams_set


def interaction_matches_strict(it: Dict[str, Any], meds_set: set, fams_set: set, fam_map: Dict[str, set]) -> bool:
    a = normalize(it["A"]) if it.get("A") else ""
    b = normalize(it["B"]) if it.get("B") else ""
    a_fam = canonical_family_key(a, fam_map)
    b_fam = canonical_family_key(b, fam_map)
    if a_fam:
        matched_a = fam_map[a_fam] & meds_set
    else:
        matched_a = {a} if a in meds_set else set()
    if b_fam:
        matched_b = fam_map[b_fam] & meds_set
    else:
        matched_b = {b} if b in meds_set else set()
    if not matched_a or not matched_b:
        return False
    for da in matched_a:
        for db in matched_b:
            if da != db:
                return True
    return False


# -----------------
# Main Analysis Function
# -----------------

def analyse_ordonnance(image_path: str) -> Dict[str, Any]:
    """Analyse une ordonnance via Gemini + bases locales et renvoie :
    { "medicaments": [...], "interactions": [...], "conseils": [...] }
    """
    # --- Chargement DB DCI ---
    try:
        correspondance_dci = load_dci_db(DCI_DB_PATH)
    except Exception as e:
        raise RuntimeError(f"Erreur chargement DB DCI : {e}")

    # --- Prompt pour Gemini ---
    prompt_text = (
        "À partir de cette image d'ordonnance médicale, extrais les informations suivantes pour chaque médicament : "
        "nom, dosage, posologie, et forme s'il est visible. "
        "Formate le résultat en JSON sous forme d'une liste : "
        "[{\"nom\": \"...\", \"dosage\": \"...\", \"posologie\": \"...\", \"forme\": \"...\"}]. "
        "Ne renvoie rien d'autre que du JSON pur."
    )

    # --- Envoi image à Gemini ---
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"Image introuvable : {image_path}")
    image = Image.open(image_path)
    response = model.generate_content([prompt_text, image])
    if not response or not getattr(response, "text", None):
        raise RuntimeError("L'IA n'a pas renvoyé de texte valide.")

    json_string = response.text.strip()
    if json_string.startswith("```json"):
        json_string = json_string[7:]
    if json_string.endswith("```"):
        json_string = json_string[:-3]

    try:
        ordonnance_data = json.loads(json_string.strip())
    except json.JSONDecodeError as e:
        raise RuntimeError(
            f"Impossible de décoder le JSON renvoyé par IA: {e}\n"
            f"Raw: {json_string[:400]}"
        )

    # --- Conversion nom commercial -> DCI ---
    medicaments_avec_dci: List[Dict[str, Any]] = []
    for medicament in ordonnance_data:
        nom_brut = medicament.get("nom")
        dci = ""
        if nom_brut:
            nom_norm = normalize(nom_brut)
            dci = correspondance_dci.get(nom_norm, "")
        
        medicaments_avec_dci.append(
            {
                "nom": nom_brut or "",
                "dci": dci or "",
                "dosage": medicament.get("dosage"),
                "posologie": medicament.get("posologie"),
                "forme": medicament.get("forme"),
            }
        )

    # --- Si moins de 2 médicaments, pas d'interaction ---
    dci_list = [normalize(m["dci"]) for m in medicaments_avec_dci if m.get("dci")]
    if len(dci_list) < 2:
        return {
            "medicaments": medicaments_avec_dci, 
            "interactions": [], 
            "conseils": []
        }

    # --- Détection interactions ---
    fam_map = load_familles(FAMILLES_MAPPING_PATH) if os.path.exists(FAMILLES_MAPPING_PATH) else {}
    if fam_map:
        rev_map = build_reverse_map(fam_map)
        meds_set, fams_set = expand_patient_strict(dci_list, rev_map)
        matches = [it for it in load_interactions_from_excel(THESAURUS_EXCEL_PATH) if interaction_matches_strict(it, meds_set, fams_set, fam_map)]
    else:
        dci_norm_list = [normalize(d) for d in dci_list if d]
        matches = []
        interactions_db = load_interactions_from_excel(THESAURUS_EXCEL_PATH)
        for it in interactions_db:
            a_norm = normalize(it.get("A", ""))
            b_norm = normalize(it.get("B", ""))
            for dci1, dci2 in combinations(dci_norm_list, 2):
                if (dci1 in a_norm and dci2 in b_norm) or (dci1 in b_norm and dci2 in a_norm):
                    matches.append(it)

    results = deduplicate_interactions(matches)
    for r in results:
        if not r.get("Details") or not str(r.get("Details")).strip():
            r["Details"] = None

    # --- Chargement et correspondance des conseils ---
    conseils_db = load_conseils(CONSEILS_PATH) if os.path.exists(CONSEILS_PATH) else []
    conseils_associes: List[Dict[str, str]] = []
    
    for med in medicaments_avec_dci:
        if med.get("dci"):
            med_dci = med["dci"]
            med_forme = med.get("forme", "") or ""
            
            for c in conseils_db:
                if (
                    c["dci"] == normalize(med_dci) and
                    (c["forme"] == normalize(med_forme) or not c["forme"])
                ):
                    conseil_text = f"{c['type_conseil']}: {c['texte']}"
                    conseils_associes.append({
                        "dci": med_dci,           # Original DCI
                        "forme": med_forme,       # Medication form
                        "display_dci": f"{med_dci} ({med_forme})" if med_forme else med_dci,  # Combined display
                        "conseil": conseil_text
                    })

    return {
        "medicaments": medicaments_avec_dci,
        "interactions": results,
        "conseils": conseils_associes
    }