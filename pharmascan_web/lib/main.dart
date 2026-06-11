import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

// Pages
import 'pages/login.dart';
import 'pages/ordonnances.dart';
import 'pages/plan.dart';
import 'pages/chat.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Paris')); 
  runApp(const PharmaScanWebApp());
}

class PharmaScanWebApp extends StatelessWidget {
  const PharmaScanWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PharmaScan Web',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      home: const LoginPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _selectedItem = 'Dashboard';

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
                    _navItem(context, 'Plans de prise'),
                    _navItem(context, 'Paramètres'),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
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
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top bar
                            Row(
                              children: [
                                const Spacer(),
                                IconButton(
                                  icon: Image.asset('images/icons/mes.png',
                                      height: 24),
                                  onPressed: () {},
                                ),
                                IconButton(
                                  icon: Image.asset('images/icons/notif.png',
                                      height: 24),
                                  onPressed: () {},
                                ),
                                const SizedBox(width: 10),
                                const CircleAvatar(
                                  backgroundImage: AssetImage(
                                      'images/icons/Ellipse 1.png'),
                                )
                              ],
                            ),
                            const SizedBox(height: 30),

                            // Search bar
                            TextField(
                              decoration: InputDecoration(
                                hintText: 'Rechercher',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),

                            const Text(
                              'Bienvenue Dr.Amine Mnasri !',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 30),

                            // Upload section
                            Center(
                              child: Container(
                                width: 500,
                                height: 150,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.grey.shade300, width: 2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.upload,
                                          size: 40,
                                          color: Color.fromARGB(
                                              255, 247, 246, 246)),
                                      SizedBox(height: 10),
                                      Text(
                                          'Choisissez un fichier ou faites-le glisser ici'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            Center(
                              child: ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFB7EACF),
                                  foregroundColor: Colors.black,
                                ),
                                child: const Text("Analyser l'ordonnance"),
                              ),
                            ),
                            const SizedBox(height: 30),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _statBox('Reçues aujourd’hui', '5'),
                                _statBox('Terminées', '12'),
                                _statBox('En attente', '3'),
                              ],
                            ),
                            const SizedBox(height: 40),

                            const Text(
                              'Ordonnances récentes',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),

                            Align(
                              alignment: Alignment.center,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 800),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('Patient')),
                                      DataColumn(label: Text('Date')),
                                      DataColumn(label: Text('Statut')),
                                      DataColumn(label: Text('Action')),
                                    ],
                                    rows: [
                                      DataRow(cells: [
                                        const DataCell(Text('Amal Ben Salem')),
                                        const DataCell(Text('24/04')),
                                        const DataCell(
                                            Text('Terminée',
                                                style: TextStyle(
                                                    color: Colors.green))),
                                        DataCell(ElevatedButton(
                                            onPressed: () {},
                                            child: const Text('Voir'))),
                                      ]),
                                      DataRow(cells: [
                                        const DataCell(Text('Salma Mbarek')),
                                        const DataCell(Text('24/04')),
                                        const DataCell(
                                            Text('En attente',
                                                style: TextStyle(
                                                    color: Colors.orange))),
                                        DataCell(ElevatedButton(
                                            onPressed: () {},
                                            child: const Text('Voir'))),
                                      ]),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, String title) {
    final isSelected = _selectedItem == title;
    final user = FirebaseAuth.instance.currentUser;

    return _HoverableSidebarItem(
      title: title,
      selected: isSelected,
      onTap: () {
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Vous devez être connecté.")),
          );
          return;
        }

        setState(() => _selectedItem = title);

        if (title == 'Messages') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ChatListPage()
            ),
          );
        } else if (title == 'Ordonnances') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrdonnancePage()),
          );
        } else if (title == 'Plans de prise') {
          Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => PlanPage(
      prescriptionImage: '',  // or actual image URL
      prescriptionId: '',     // real prescription doc ID
    ),
  ),
);

        }
      },
    );
  }

  Widget _statBox(String label, String count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 5),
          Text(count,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _HoverableSidebarItem extends StatefulWidget {
  final String title;
  final bool selected;
  final VoidCallback? onTap;

  const _HoverableSidebarItem({
    required this.title,
    this.selected = false,
    this.onTap,
  });

  @override
  State<_HoverableSidebarItem> createState() => _HoverableSidebarItemState();
}

class _HoverableSidebarItemState extends State<_HoverableSidebarItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final bool isActive = widget.selected || _isHovering;

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
          title: Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}
