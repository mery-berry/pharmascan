import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PlanPage extends StatefulWidget {
  final String? patientName;
  final String? date;
  final String? status;
  final String prescriptionImage;
  final String prescriptionId;

  const PlanPage({
    super.key,
    this.patientName,
    this.date,
    this.status,
    required this.prescriptionImage,
    required this.prescriptionId,
  });

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  final currentUser = FirebaseAuth.instance.currentUser;
  List<Medication> medications = [Medication(name: 'Médicament 1')];

  Future<void> _savePlan() async {
  try {
    if (currentUser == null) throw 'Utilisateur non connecté';

    final prescriptionRef = FirebaseFirestore.instance
        .collection('prescriptions')
        .doc(widget.prescriptionId);

    // Save medications and plan
    for (var med in medications) {
      final medRef = med.id.isEmpty
          ? prescriptionRef.collection('medications').doc()
          : prescriptionRef.collection('medications').doc(med.id);

      await medRef.set({
        'name': med.name,
        'morning': med.morning ? 1 : 0,
        'noon': med.noon ? 1 : 0,
        'evening': med.evening ? 1 : 0,
        'bedtime': med.bedtime ? 1 : 0,
        'mealRelation': med.mealRelation,
        'durationDays': med.duration,
        'goal': med.goal,
        'notes': med.notes,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      med.id = medRef.id;

      await medRef.collection('plan').doc('plan').set({
        'duration': int.tryParse(med.duration) ?? 7,
        'startDate': med.startDate ?? FieldValue.serverTimestamp(),
        'timeslots': _getSelectedTimeslots(med),
        'medicationName': med.name,
      });

      // Initialize taken documents
      for (var slot in _getSelectedTimeslots(med)) {
        final takenRef = medRef.collection('taken').doc(slot);
        await takenRef.set({
          'istaken': false,
          'takenAt': null,
        });
      }
    }

    // Update prescription status
    await prescriptionRef.set({
      'status': 'Plan validé',
      'planValidatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Firestore notification only
    final prescriptionData = await prescriptionRef.get();
    final patientId = prescriptionData['createdby'];
    if (patientId != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .collection('notifications')
          .add({
        'title': 'Plan de prise validé ✅',
        'body': 'Votre plan de prise a été créé par votre pharmacien.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'plan',
        'prescriptionId': widget.prescriptionId,
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan de prise enregistré avec succès!')),
      );
      _navigateToOrdonnances();
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
}


  // ✅ New method to navigate to ordonnances page
  void _navigateToOrdonnances() {
    // Navigate back to the ordonnances page
    // This assumes your ordonnances page is in a file called 'ordonnances.dart'
    // and the main class is named 'OrdonnancesPage'
    
    // First pop the current plan page
    Navigator.pop(context);
    
    // If you need to refresh the ordonnances page, you can use a callback or just rely on Firestore updates
    // Since you're updating Firestore, the ordonnances page should automatically update via StreamBuilder
  }

  List<String> _getSelectedTimeslots(Medication med) {
    final slots = <String>[];
    if (med.morning) slots.add('morning');
    if (med.noon) slots.add('noon');
    if (med.evening) slots.add('evening');
    if (med.bedtime) slots.add('bedtime');
    return slots;
  }

  void _addMedication() {
    setState(() {
      medications.add(Medication(name: 'Médicament ${medications.length + 1}'));
    });
  }

  void _removeMedication(int index) {
    setState(() {
      medications.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            color: const Color(0xFFF6F6F6),
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Image.asset('images/icons/pharma_logo.png', height: 60),
                    const SizedBox(height: 30),
                    _navItem(context, 'Dashboard'),
                    _navItem(context, 'Ordonnances'),
                    _navItem(context, 'Messages'),
                    _navItem(context, 'Plans de prise', selected: true),
                    _navItem(context, 'Paramètres'),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: Image.asset('images/icons/logout.png', height: 16),
                    label: const Text('Déconnexion'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDFF5E1),
                      foregroundColor: Colors.green.shade700,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  // Top bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Image.asset('images/icons/mes.png', height: 24),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: Image.asset('images/icons/notif.png', height: 24),
                        onPressed: () {},
                      ),
                      const SizedBox(width: 10),
                      const CircleAvatar(
                        backgroundImage: AssetImage('images/icons/Ellipse 1.png'),
                      )
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Card Content
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 800,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back),
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "Plan de prise personnalisé",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Dynamic Medications List
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      for (int i = 0; i < medications.length; i++)
                                        _medicationCard(i),
                                      const SizedBox(height: 20),
                                      ElevatedButton.icon(
                                        onPressed: _addMedication,
                                        icon: const Icon(Icons.add),
                                        label: const Text('Ajouter un médicament'),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green.shade100,
                                            foregroundColor: Colors.green.shade800),
                                      ),
                                      const SizedBox(height: 20),
                                      ElevatedButton(
                                        onPressed: _savePlan,
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFC6F6CF),
                                            foregroundColor: Colors.black),
                                        child: const Text('Valider le plan de prise'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _medicationCard(int index) {
    final med = medications[index];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: med.name,
                    decoration: const InputDecoration(labelText: 'Nom du médicament'),
                    onChanged: (val) => med.name = val,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeMedication(index),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(value: med.morning, onChanged: (val) => setState(() => med.morning = val!)),
                const Text('Matin'),
                Checkbox(value: med.noon, onChanged: (val) => setState(() => med.noon = val!)),
                const Text('Midi'),
                Checkbox(value: med.evening, onChanged: (val) => setState(() => med.evening = val!)),
                const Text('Soir'),
                Checkbox(value: med.bedtime, onChanged: (val) => setState(() => med.bedtime = val!)),
                const Text('Coucher'),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Lien avec le repas'),
              value: med.mealRelation,
              items: ['Avant le repas', 'Pendant le repas', 'Après le repas']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => med.mealRelation = val!),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: med.duration,
              decoration: const InputDecoration(labelText: 'Durée (en jours)'),
              onChanged: (val) => med.duration = val,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: med.goal,
              decoration: const InputDecoration(labelText: 'Objectif thérapeutique'),
              onChanged: (val) => med.goal = val,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: med.notes,
              decoration: const InputDecoration(labelText: 'Notes spécifiques'),
              onChanged: (val) => med.notes = val,
            ),
            const SizedBox(height: 10),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Date de début (YYYY-MM-DD HH:mm)'),
              onChanged: (val) => med.startDate = DateTime.tryParse(val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, String title, {bool selected = false}) {
    return _HoverableSidebarItem(
      title: title,
      selected: selected,
      onTap: () {
        // Navigate to ordonnances when clicked
        if (title == 'Ordonnances') {
          Navigator.pop(context);
        }
      },
    );
  }
}

class _HoverableSidebarItem extends StatefulWidget {
  final String title;
  final bool selected;
  final VoidCallback? onTap;

  const _HoverableSidebarItem({required this.title, this.selected = false, this.onTap});

  @override
  State<_HoverableSidebarItem> createState() => _HoverableSidebarItemState();
}

class _HoverableSidebarItemState extends State<_HoverableSidebarItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.selected || _isHovering;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: isActive
            ? BoxDecoration(
                color: const Color(0xFFC6F6CF),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: ListTile(
          title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w500)),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}

class Medication {
  String id ;
  String name;
  bool morning;
  bool noon;
  bool evening;
  bool bedtime;
  String mealRelation;
  String duration;
  String goal;
  String notes;
  DateTime? startDate;

  Medication({
    this.id = '',
    required this.name,
    this.morning = false,
    this.noon = false,
    this.evening = false,
    this.bedtime = false,
    this.mealRelation = 'Avant le repas',
    this.duration = '',
    this.goal = '',
    this.notes = '',
    this.startDate,
  });
    
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'morning': morning ? 1 : 0,
      'noon': noon ? 1 : 0,
      'evening': evening ? 1 : 0,
      'bedtime': bedtime ? 1 : 0,
      'mealRelation': mealRelation,
      'durationDays': duration,
      'goal': goal,
      'notes': notes,
      'startDate': startDate,
    };
  }
   
  factory Medication.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Medication(
      id: doc.id,
      name: data['name'] ?? '',
      morning: (data['morning'] ?? 0) == 1,
      noon: (data['noon'] ?? 0) == 1,
      evening: (data['evening'] ?? 0) == 1,
      bedtime: (data['bedtime'] ?? 0) == 1,
      mealRelation: data['mealRelation'] ?? 'Avant le repas',
      duration: data['durationDays'] ?? '',
      goal: data['goal'] ?? '',
      notes: data['notes'] ?? '',
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : null,
    );
  }
}