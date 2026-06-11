import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'red.dart';
import 'green.dart';
import 'blue.dart';
import 'plan.dart';

class DetailOrdonnancePage extends StatefulWidget {
  final String patientName;
  final String patientId; // ✅ Add this
  final String date;
  final String status;
  final String? prescriptionImage;
  final String prescriptionId;

  const DetailOrdonnancePage({
    super.key,
    required this.patientName,
    required this.patientId, // ✅ required
    required this.date,
    required this.status,
    required this.prescriptionImage,
    required this.prescriptionId,
  });

  @override
  State<DetailOrdonnancePage> createState() => _DetailOrdonnancePageState();
}

class _DetailOrdonnancePageState extends State<DetailOrdonnancePage> {
  Future<String>? _downloadUrl;

  @override
  void initState() {
    super.initState();
    _downloadUrl = _getDownloadUrl();
  }
Future<void> _markAsReady() async {
  try {
    print('🔄 Marking prescription as ready: ${widget.prescriptionId}');
    
    // First, update the prescription status
    final prescriptionRef = FirebaseFirestore.instance
        .collection('prescriptions')
        .doc(widget.prescriptionId);

    await prescriptionRef.update({
      'status': 'Terminée',
      'completedAt': FieldValue.serverTimestamp(),
    });

    // Then update the corresponding order
    final orderRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.prescriptionId); // Using prescriptionId as orderId

    final orderDoc = await orderRef.get();
    
    if (orderDoc.exists) {
      await orderRef.update({
        'status': 'Terminée',
        'completedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Order updated successfully');
    } else {
      print('⚠️ No order found, creating one...');
      // Create the order if it doesn't exist
      await orderRef.set({
        'prescriptionId': widget.prescriptionId,
        'createdby': widget.patientId,
        'pharmacyId': 'default_pharmacy', // You might want to get this from somewhere
        'status': 'Terminée',
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ La médication a été marquée comme prête!')),
      );
      
      // Refresh the page to show updated status
      setState(() {});
    }
  } catch (e) {
    print('❌ Error marking prescription as ready: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
}

  Future<String> _getDownloadUrl() async {
    try {
      if (widget.prescriptionImage == null || widget.prescriptionImage!.isEmpty) {
        return '';
      }

      print('🔄 Getting download URL from Firebase Storage...');
      
      // Extract path from URL
      final fullUrl = widget.prescriptionImage!;
      final oIndex = fullUrl.indexOf('/o/');
      if (oIndex != -1) {
        final afterO = fullUrl.substring(oIndex + 3);
        final questionMarkIndex = afterO.indexOf('?');
        final storagePath = questionMarkIndex != -1 
            ? Uri.decodeFull(afterO.substring(0, questionMarkIndex))
            : Uri.decodeFull(afterO);
        
        print('📁 Storage path: $storagePath');
        
        // Get download URL
        final ref = FirebaseStorage.instance.ref().child(storagePath);
        final downloadUrl = await ref.getDownloadURL();
        print('✅ Download URL obtained');
        return downloadUrl;
      }
      
      return widget.prescriptionImage!;
    } catch (e) {
      print('❌ Error getting download URL: $e');
      return widget.prescriptionImage ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    print('=== IMAGE DEBUG ===');
    print('URL: ${widget.prescriptionImage}');
    print('URL Length: ${widget.prescriptionImage?.length ?? 0}');
    print('=== END DEBUG ===');

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
                        backgroundImage:
                            AssetImage('images/icons/Ellipse 1.png'),
                      )
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Boxed Content + Button
                  Expanded(
                     child: SingleChildScrollView(
    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 800,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.arrow_back_ios),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      "Détail de l'ordonnance",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.patientName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        if (widget.status.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: widget.status == 'En attente'
                                                  ? Colors.orange.shade100
                                                  : widget.status == 'Terminée'
                                                      ? Colors.green.shade100
                                                      : Colors.grey.shade200,
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              widget.status,
                                              style: TextStyle(
                                                color: widget.status == 'En attente'
                                                    ? Colors.orange
                                                    : widget.status == 'Terminée'
                                                        ? Colors.green
                                                        : Colors.grey,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        if (widget.date.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              widget.date,
                                              style: const TextStyle(
                                                  color: Colors.grey),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const Text(
                                      'Lecture assistée par IA',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 30),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Prescription Image
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey.shade300),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: _buildPrescriptionImage(),
                                      ),
                                    ),
                                    const SizedBox(width: 25),
                                    // Icon Cards Column
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        children: [
                                            _iconCard(
                                            context,
                                            'images/icons/red.png',
                                            "Lecture de l'ordonnance",
                                            FutureBuilder<String>(
                                              future: _downloadUrl,
                                              builder: (context, snapshot) {
                                                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                                  return Center(child: Text('Image non disponible'));
                                                }
                                                return RedPage(
                                                  patientName: widget.patientName,
                                                  date: widget.date,
                                                  status: widget.status,
                                                  prescriptionImage: snapshot.data!, // <- backend call inside RedPage
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 20),                                       
                                          _iconCard(
                                            context,
                                            'images/icons/green.png',
                                            'Interactions médicamenteuses',
                                            FutureBuilder<String>(
                                              future: _downloadUrl,
                                              builder: (context, snapshot) {
                                                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                                  return Center(child: Text('Image non disponible'));
                                                }
                                                return GreenPage(
                                                  patientName: widget.patientName,
                                                  date: widget.date,
                                                  status: widget.status,
                                                  prescriptionImage: snapshot.data!, // <- backend call inside GreenPage
                                                );
                                              },
                                            ),
                                          ),

                                          const SizedBox(height: 20),
                                          _iconCard(
                                            context,
                                            'images/icons/blue.png',
                                            'Aide au conseil',
                                            BluePage(
                                              patientName: widget.patientName,
                                              date: widget.date,
                                              status: widget.status,
                                              prescriptionImage: widget.prescriptionImage!,
                                            ),
                                          ),
                                          SizedBox(
                                          width: 300,
                                          child: ElevatedButton(
                                            onPressed: _markAsReady,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue.shade400,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: const [
                                                Text('Médication prête à prendre', style: TextStyle(fontSize: 16)),
                                                SizedBox(width: 8),
                                                Icon(Icons.inventory_2, size: 16),
                                              ],
                                            ),
                                          ),
                                        ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),),
                          
                          const SizedBox(height: 25),
                          SizedBox(
                            width: 300,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PlanPage(
                                      patientName: widget.patientName,
                                      date: widget.date,
                                      status: widget.status,
                                      prescriptionImage: widget.prescriptionImage ?? '',
                                      prescriptionId: widget.prescriptionId,
                                    ),
                                  ),
                                );
                                
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC6F6CF),
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text('Passer vers le plan de prise',
                                      style: TextStyle(fontSize: 16)),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_ios, size: 16),
                                  
                                ],
                              ),
                            ),
                          ),
                        ],
                        
                      ),
                    ),
                  ),),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

Widget _buildPrescriptionImage() {
  return FutureBuilder<String>(
    future: _downloadUrl,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      final downloadUrl = snapshot.data;
      if (downloadUrl == null || downloadUrl.isEmpty) {
        return _buildEmptyState();
      }

      print('🎯 Loading image directly: $downloadUrl');

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          downloadUrl,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 500),
              child: child,
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            final progress = loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(value: progress),
                  const SizedBox(height: 10),
                  const Text('Chargement de l’image...'),
                ],
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('❌ Image load error: $error');
            final proxyUrl =
                'https://corsproxy.io/?${Uri.encodeFull(downloadUrl)}';
            return Image.network(
              proxyUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return _buildErrorState('Erreur de chargement: $error');
              },
            );
          },
        ),
      );
    },
  );
}


  Widget _buildErrorState(String error) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error, color: Colors.red, size: 50),
        SizedBox(height: 16),
        Text(
          'Impossible de charger l\'image',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          'Erreur: $error',
          style: TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _downloadUrl = _getDownloadUrl();
            });
          },
          child: Text('Réessayer'),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image_not_supported, color: Colors.grey, size: 50),
        SizedBox(height: 16),
        Text("Aucune image disponible"),
      ],
    );
  }

  Widget _iconCard(BuildContext context, String iconPath, String title, Widget destination) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => destination)),
      child: HoverableIconCard(iconPath: iconPath, title: title),
    );
  }

  Widget _navItem(BuildContext context, String title, {bool selected = false}) {
    return HoverableSidebarItem(
      title: title,
      selected: selected,
      onTap: () {
        switch (title) {
          case 'Dashboard':
            Navigator.pushNamed(context, '/');
            break;
          case 'Ordonnances':
            Navigator.pushNamed(context, '/ordonnances');
            break;
          case 'Messages':
            Navigator.pushNamed(context, '/mes');
            break;
          case 'Plans de prise':
            Navigator.pushNamed(context, '/plan');
            break;
        }
      },
    );
  }
}

class HoverableIconCard extends StatefulWidget {
  final String iconPath;
  final String title;

  const HoverableIconCard({Key? key, required this.iconPath, required this.title})
      : super(key: key);

  @override
  HoverableIconCardState createState() => HoverableIconCardState();
}

class HoverableIconCardState extends State<HoverableIconCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isHovering ? const Color(0xFFF0F0F0) : Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Image.asset(widget.iconPath, height: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: _isHovering ? Colors.black : Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }
}

class HoverableSidebarItem extends StatefulWidget {
  final String title;
  final bool selected;
  final VoidCallback? onTap;

  const HoverableSidebarItem({required this.title, this.selected = false, this.onTap});

  @override
  State<HoverableSidebarItem> createState() => HoverableSidebarItemState();
}

class HoverableSidebarItemState extends State<HoverableSidebarItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.selected || _isHovering;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
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