from fastapi import FastAPI, UploadFile, File  # type:ignore
from fastapi.middleware.cors import CORSMiddleware  # type:ignore
from pydantic import BaseModel  # type:ignore
import requests  # type:ignore
import tempfile
import os
from analyse_ordonnance import analyse_ordonnance

# ----- Priorité gravité pour tri -----
GRAVITY_PRIORITY = {
    "CONTRE-INDICATION": 3,
    "ASSOCIATION DECONSEILLEE": 2,
    "PRÉCAUTION D'EMPLOI": 1,
    "PRECAUTION D'EMPLOI": 1,
    "A PRENDRE EN COMPTE": 0,
    None: 0
}

# ----- Initialisation de l'application -----
app = FastAPI(title="API Ordonnance Pharmacien v4")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # pour développement
    allow_methods=["*"],
    allow_headers=["*"],
)

# ----- Modèle de requête -----
class AnalyseRequest(BaseModel):
    image_url: str


# ----- Endpoint : analyse via URL -----
@app.post("/analyser_ordonnance_url/")
async def analyser_ordonnance_url_endpoint(req: AnalyseRequest):
    """
    Analyse une ordonnance à partir d'une URL d'image.
    """
    try:
        # Télécharger l'image depuis l'URL
        resp = requests.get(req.image_url)
        resp.raise_for_status()

        # Sauvegarde temporaire de l'image pour analyse
        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
            tmp.write(resp.content)
            tmp_path = tmp.name

        # Analyse de l'ordonnance via Gemini + bases locales
        resultat = analyse_ordonnance(tmp_path)

        # Nettoyage du fichier temporaire
        os.remove(tmp_path)

        # Formatage pour l'affichage
        return formater_resultat(resultat)

    except Exception as e:
        return {"error": f"Erreur lors de l'analyse : {e}"}


# ----- Endpoint : upload direct d'image -----
@app.post("/analyser_ordonnance_fichier/")
async def analyser_ordonnance_fichier_endpoint(file: UploadFile = File(...)):
    """
    Analyse une ordonnance uploadée directement.
    """
    try:
        contents = await file.read()

        with tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(file.filename)[-1]) as tmp:
            tmp.write(contents)
            tmp_path = tmp.name

        resultat = analyse_ordonnance(tmp_path)

        os.remove(tmp_path)
        return formater_resultat(resultat)

    except Exception as e:
        return {"error": f"Erreur lors de l'analyse : {e}"}


# ----- Fonction utilitaire : formatage du résultat -----
def formater_resultat(resultat):
    """
    Uniformise les clés et trie les interactions par gravité.
    """
    # Ensure resultat is not None
    if resultat is None:
        resultat = {}
    
    # Medicaments - always return list
    medicaments_affichage = []
    raw_medicaments = resultat.get("medicaments", [])
    for med in raw_medicaments:
        medicaments_affichage.append({
            "nom": med.get("nom")
                or med.get("Nom")
                or med.get("DCI")
                or med.get("dci")
                or med.get("Medicament")
                or med.get("name")
                or med.get("medicament")
                or "Nom inconnu",
            "dci": med.get("dci") or med.get("DCI") or "",
            "dosage": med.get("dosage") or med.get("Dosage") or "",
            "posologie": med.get("posologie") or med.get("Posologie") or "",
            "forme": med.get("forme") or med.get("Forme") or "",
        })

    # Interactions - always return list
    interactions = resultat.get("interactions", [])
    if interactions is None:
        interactions = []
    for i in interactions:
        i["niveau"] = GRAVITY_PRIORITY.get(i.get("Gravity"), 0)
    interactions.sort(key=lambda x: x["niveau"], reverse=True)

    # Conseils - Ensure this is always a proper list
    conseils = resultat.get("conseils", [])
    
    # Double-check it's a list
    if not isinstance(conseils, list):
        conseils = []
    
    return {
        "medicaments": medicaments_affichage,
        "interactions": interactions,
        "conseils": conseils
    }


# ----- Endpoint racine -----
@app.get("/")
async def root():
    return {"message": "Bienvenue sur l'API d'analyse d'ordonnances v4"}