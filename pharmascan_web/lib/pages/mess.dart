import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> saveFcmToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'fcmToken': token,
    });
  }
}

class MessagesWebPage extends StatefulWidget {
  final String patientId;
  final String patientName;

  const MessagesWebPage({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<MessagesWebPage> createState() => _MessagesWebPageState();
}

class _MessagesWebPageState extends State<MessagesWebPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final String pharmacyId = "default_pharmacy"; // mobile path matches

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // Add message to mobile-compatible path
      await firestore
          .collection("pharmacies")
          .doc(pharmacyId)
          .collection("conversations")
          .doc(widget.patientId)
          .collection("messages")
          .add({
        "sender": "pharmacy",
        "text": text,
        "timestamp": FieldValue.serverTimestamp(),
      });

      // Update conversation summary
      await firestore
          .collection("pharmacies")
          .doc(pharmacyId)
          .collection("conversations")
          .doc(widget.patientId)
          .set({
        "lastMessage": text,
        "lastTimestamp": FieldValue.serverTimestamp(),
        "patientName": widget.patientName,
        "patientId": widget.patientId,
      }, SetOptions(merge: true));

      _controller.clear();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to send: $e")));
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final messagesRef = FirebaseFirestore.instance
        .collection("pharmacies")
        .doc(pharmacyId)
        .collection("conversations")
        .doc(widget.patientId)
        .collection("messages")
        .orderBy("timestamp", descending: false);

    return Scaffold(
      appBar: AppBar(
        title: Text("Chat with ${widget.patientName}"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: messagesRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      "No messages yet\nStart the conversation!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isMe = msg["sender"] == "pharmacy";
                    final text = msg["text"] ?? "";
                    final timestamp = msg["timestamp"] as Timestamp?;
                    final time = timestamp != null
                        ? DateFormat("hh:mm a").format(timestamp.toDate())
                        : "";

                    return MessageBubble(
                      text: text,
                      isMe: isMe,
                      time: time,
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.green),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.green[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(text),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
