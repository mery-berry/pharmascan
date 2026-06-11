import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'prescription_cache.dart';

class RedPage extends StatefulWidget {
  final String patientName;
  final String date;
  final String status;
  final String prescriptionImage;

  const RedPage({
    super.key,
    required this.patientName,
    required this.date,
    required this.status,
    required this.prescriptionImage,
  });

  @override
  State<RedPage> createState() => _RedPageState();
}

class _RedPageState extends State<RedPage> {
  Map<String, dynamic>? _result;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scanPrescription();
  }

  Future<void> _scanPrescription() async {
  print('🔄 CALLING MAIN API ENDPOINT...');
  
  // 1️⃣ Check cache first
  final cached = PrescriptionCache.get(widget.prescriptionImage);
  if (cached != null) {
    print('✅ Using cached data');
    setState(() {
      _result = cached;
      _isLoading = false;
    });
    return;
  }

  // 2️⃣ Otherwise, fetch from backend
  setState(() {
    _isLoading = true;
    _error = null;
  });

  try {
    // FORCE main API call
    final uri = Uri.parse('https://lionlike-unambulant-yolanda.ngrok-free.dev/analyser_ordonnance_url/');
    print('🚀 Calling MAIN API: $uri');
    print('📁 Image URL: ${widget.prescriptionImage}');
    
    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"image_url": widget.prescriptionImage}),
    );

    print('📥 Main API Response status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      print('✅ MAIN API RESPONSE:');
      print('   Keys: ${data.keys}');
      print('   Medicaments: ${data['medicaments']?.length ?? 0}');
      print('   Interactions: ${data['interactions']?.length ?? 0}');
      print('   Conseils: ${data['conseils']}');
      print('   Conseils is null: ${data['conseils'] == null}');
      
      PrescriptionCache.set(widget.prescriptionImage, data);

      setState(() {
        _result = data;
      });
    } else {
      print('❌ Main API Error: ${response.statusCode}');
      print('Response: ${response.body}');
      setState(() {
        _error = "Erreur API ${response.statusCode}";
      });
    }
  } catch (e) {
    print('❌ Main API Network Error: $e');
    setState(() {
      _error = "Erreur réseau: $e";
    });
  } finally {
    setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    final meds = _result?['medicaments'] ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Lecture de l'ordonnance"),
        backgroundColor: Colors.red[700],
        // NEW: Add debug button to app bar
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!,
                            style: const TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold)),
                        SizedBox(height: 20),
                        // NEW: Debug button in error state
                      ],
                    ),
                  )
                : meds.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Aucun médicament détecté."),
                            SizedBox(height: 20),
                            // NEW: Debug button in empty state
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Patient info
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "👤 Patient : ${widget.patientName}\n"
                                "📅 Date : ${widget.date}\n"
                                "📋 Statut : ${widget.status}",
                                style: const TextStyle(fontSize: 16, height: 1.6),
                              ),
                            ),
                            const SizedBox(height: 20),
                            

                            const Text(
                              "Médicaments détectés :",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            // Meds list
                            ...meds.map<Widget>((med) {
                              final nom = med['nom'] ??
                                  med['nom'] ??
                                  med['dci'] ??
                                  med['DCI'] ??
                                  med['medicament'] ??
                                  'Nom inconnu';

                              final details = [
                                if (med['dosage'] != null && med['dosage']!.toString().isNotEmpty)
                                  med['dosage'],
                                if (med['posologie'] != null && med['posologie']!.toString().isNotEmpty)
                                  med['posologie'],
                                if (med['forme'] != null && med['forme']!.toString().isNotEmpty)
                                  med['forme'],
                              ].join(' • ');

                              return Card(
                                color: Colors.red[50],
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: const Icon(Icons.medication_liquid, color: Colors.red),
                                  title: Text(
                                    nom,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    details.isNotEmpty ? details : 'Aucune posologie indiquée',
                                    style: const TextStyle(color: Colors.black54),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
      ),
    );
  }
}