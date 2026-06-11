import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'detail.dart';
import 'plan.dart';
import 'chat.dart';
import '../main.dart';

class OrdonnancePage extends StatefulWidget {
  const OrdonnancePage({super.key});

  @override
  State<OrdonnancePage> createState() => _OrdonnancePageState();
}

class _OrdonnancePageState extends State<OrdonnancePage> {
  final user = FirebaseAuth.instance.currentUser;
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text('User not logged in'));

    final prescriptionsRef = FirebaseFirestore.instance
        .collection('prescriptions')
        .orderBy('createdAt', descending: true);

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
                    _navItem(context, 'Ordonnances', selected: true),
                    _navItem(context, 'Messages'),
                    _navItem(context, 'Plans de prise'),
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
                      foregroundColor: Colors.green,
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

          // Main content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar
                  Row(
                    children: [
                      const Spacer(),
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
                  Row(
                    children: [
                      Image.asset('images/icons/his.png', height: 24),
                      const SizedBox(width: 10),
                      const Text(
                        'Historique des ordonnances',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Search bar
                  TextField(
                    onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Rechercher par ID ou nom du patient',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  Row(
                    children: const [
                      Expanded(child: Text('Ordonnance', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(child: Text('Patient', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(child: Text('Etat de commande', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const Divider(),

                  // Prescription list
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: prescriptionsRef.snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                        final docs = snapshot.data!.docs.where((doc) {
                          final id = doc.id.toLowerCase();
                          return id.contains(searchQuery);
                        }).toList();

                        if (docs.isEmpty) return const Center(child: Text('Aucune ordonnance trouvée'));

                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final rawData = doc.data();
                            final Map<String, dynamic> data =
                                rawData is Map<String, dynamic> ? rawData : {};

                            // Safe extraction
                            final status = data.containsKey('status') && data['status'] != null
                                ? data['status'].toString()
                                : '';

                            final date = data.containsKey('date') && data['date'] != null
                                ? data['date'].toString()
                                : '';

                            final patientName = data.containsKey('patientName') && data['patientName'] != null
                                ? data['patientName'].toString()
                                : 'Patient';

                            final prescriptionImage = data.containsKey('prescriptionImage') && data['prescriptionImage'] != null
                                ? data['prescriptionImage'].toString().replaceAll('\n', '').trim()
                                : '';

                            print("Doc ${doc.id} → prescriptionImage: $prescriptionImage");

                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DetailOrdonnancePage(
                                      patientName: patientName,
                                      patientId: data['createdby'], // ✅ Firestore UID
                                      date: date,
                                      status: status,
                                      prescriptionImage: prescriptionImage,
                                      prescriptionId: doc.id,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      margin: const EdgeInsets.only(right: 15),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue.shade100),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Text('Ordonnance ${doc.id}')),
                                    Expanded(child: Text(patientName)),
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: status.isEmpty ? Text(date) : _statusLabel(status),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusLabel(String status) {
    Color color = Colors.grey;
    Color bg = Colors.grey.shade100;

    if (status == 'Terminée') {
      color = Colors.green;
      bg = Colors.green.shade100;
    } else if (status == 'En attente') {
      color = Colors.orange;
      bg = Colors.orange.shade100;
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 60, maxWidth: 100),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _navItem(BuildContext context, String title, {bool selected = false}) {
    return _HoverableSidebarItem(
      title: title,
      selected: selected,
      onTap: () {
        if (title == 'Messages') {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatListPage()),
          );
        } else if (title == 'Plans de prise') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PlanPage(prescriptionImage: '', prescriptionId: ''),
            ),
          );
        } else if (title == 'Dashboard') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardPage()),
          );
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
            ? BoxDecoration(color: const Color(0xFFC6F6CF), borderRadius: BorderRadius.circular(8))
            : null,
        child: ListTile(
          title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w500)),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}
