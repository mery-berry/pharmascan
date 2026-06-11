import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'mess.dart'; // MessagesWebPage

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    const pharmacyDoc = "default_pharmacy";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Conversations"),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("pharmacies")
            .doc(pharmacyDoc)
            .collection("conversations")
            .orderBy("lastTimestamp", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final conversations = snapshot.data!.docs;
          if (conversations.isEmpty) return const Center(child: Text("No conversations yet"));

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final doc = conversations[index];
              final data = doc.data() as Map<String, dynamic>;
              final patientId = data["patientId"] ?? doc.id;
              final lastMessage = data["lastMessage"] ?? "";
              final lastTime = _formatTimestamp(data["lastTimestamp"]);

              // ✅ Always fetch from users collection
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection("users").doc(patientId).get(),
                builder: (context, userSnap) {
                  String patientName = "Unknown";
                  if (userSnap.hasData && userSnap.data!.exists) {
                    final userData = userSnap.data!.data() as Map<String, dynamic>;
                    patientName = userData["fullname"] ?? userData["username"] ?? patientId;
                  }

                  return ConversationTile(
                    patientId: patientId,
                    patientName: patientName,
                    lastMessage: lastMessage,
                    lastTime: lastTime,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "";
    final date = (timestamp as Timestamp).toDate();
    return DateFormat("hh:mm a").format(date);
  }
}

class ConversationTile extends StatelessWidget {
  final String patientId;
  final String patientName;
  final String lastMessage;
  final String lastTime;

  const ConversationTile({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.lastMessage,
    required this.lastTime,
  });

  @override
  Widget build(BuildContext context) {

    return ListTile(
      leading: CircleAvatar(child: Text(patientName[0].toUpperCase())),
      title: Text(patientName),
      subtitle: Text(lastMessage),
      trailing: Text(lastTime),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MessagesWebPage(
              patientId: patientId,
              patientName: patientName,
            ),
          ),
        );
      },
    );
  }
}
