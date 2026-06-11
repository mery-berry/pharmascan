import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'prescription_cache.dart';
import 'api_helper.dart';

class GreenPage extends StatefulWidget {
  final String patientName;
  final String date;
  final String status;
  final String prescriptionImage;

  const GreenPage({
    super.key,
    required this.patientName,
    required this.date,
    required this.status,
    required this.prescriptionImage,
  });

  @override
  State<GreenPage> createState() => _GreenPageState();
}

class _GreenPageState extends State<GreenPage> {
  late Future<Map<String, dynamic>> _futureData;

  @override
  void initState() {
    super.initState();
    _futureData = _fetchData();
  }

  Future<Map<String, dynamic>> _fetchData() async {
    final cached = PrescriptionCache.get(widget.prescriptionImage);
    if (cached != null) return cached;

    final res = await http.post(
      ApiHelper.analyserOrdonnanceUrl(),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"image_url": widget.prescriptionImage}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      PrescriptionCache.set(widget.prescriptionImage, data);
      return data;
    } else {
      throw Exception("API error ${res.statusCode}");
    }
  }

  // --- Gravité → couleur ---
  Color _getGravityColor(String? gravity) {
    if (gravity == null) return Colors.grey;
    switch (gravity.toUpperCase()) {
      case "CONTRE-INDICATION":
        return Colors.red;
      case "ASSOCIATION DECONSEILLEE":
        return Colors.orange;
      case "PRÉCAUTION D'EMPLOI":
      case "PRECAUTION D'EMPLOI":
        return Colors.amber;
      case "A PRENDRE EN COMPTE":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInteractionCard(Map<String, dynamic> interaction) {
    final gravity = interaction['Gravity'] ?? '';
    final color = _getGravityColor(gravity);

    return Card(
      color: Colors.green[50],
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(Icons.warning, color: color),
        title: Text(
          "${interaction['A']} + ${interaction['B']}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(interaction['Details'] ?? ''),
        trailing: Text(
          gravity,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Interactions médicamenteuses"),
        backgroundColor: Colors.green[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _futureData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Erreur: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            final data = snapshot.data ?? {};
            final interactions = data['interactions'] ?? [];

            if (interactions.isEmpty) {
              return const Center(
                child: Text("Aucune interaction détectée."),
              );
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ Patient info section with emojis
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
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
                    "⚠️ Interactions détectées :",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  ...interactions.map<Widget>(
                    (item) =>
                        _buildInteractionCard(item as Map<String, dynamic>),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
