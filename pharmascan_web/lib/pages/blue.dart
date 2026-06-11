import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'prescription_cache.dart';
import 'api_helper.dart';

class BluePage extends StatefulWidget {
  final String prescriptionImage;
  final String patientName;
  final String date;
  final String status;

  const BluePage({
    super.key,
    required this.prescriptionImage,
    required this.patientName,
    required this.date,
    required this.status,
  });

  @override
  State<BluePage> createState() => _BluePageState();
}

class _BluePageState extends State<BluePage> {
  late Future<List<Map<String, dynamic>>> _futureConseils;

  @override
  void initState() {
    super.initState();
    _futureConseils = _fetchConseils();
  }

  Future<List<Map<String, dynamic>>> _fetchConseils() async {
    final cached = PrescriptionCache.get(widget.prescriptionImage);
    if (cached != null) {
      return List<Map<String, dynamic>>.from(cached['conseils'] ?? []);
    }

    final res = await http.post(
      ApiHelper.analyserOrdonnanceUrl(),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"image_url": widget.prescriptionImage}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      PrescriptionCache.set(widget.prescriptionImage, data);
      return List<Map<String, dynamic>>.from(data['conseils'] ?? []);
    } else {
      throw Exception("API error ${res.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Aide au conseil"),
        backgroundColor: Colors.blue[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _futureConseils,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text('Erreur: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red)));
            }

            final conseils = snapshot.data ?? [];
            if (conseils.isEmpty) {
              return const Center(
                  child: Text("Aucun conseil disponible pour cette ordonnance."));
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
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
                    "💡 Conseils :",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...conseils.map<Widget>((c) => Card(
                    color: Colors.blue[50],
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: const Icon(Icons.medical_services, color: Colors.blue),
                      title: Text(
                        c['display_dci'] ?? c['dci'] ?? 'Médicament', // Use display_dci if available
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        c['conseil'] ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  )),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}