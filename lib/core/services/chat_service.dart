import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Sends a message inside a specific chat room
  Future<void> sendMessage(String chatRoomId, String messageText) async {
    final String currentUserId = _auth.currentUser!.uid;
    final String userEmail = _auth.currentUser!.email ?? "user@mentorlinks.com";
    final Timestamp timestamp = Timestamp.now();

    // Message data structure
    Map<String, dynamic> messageData = {
      'senderId': currentUserId,
      'senderEmail': userEmail,
      'message': messageText,
      'timestamp': timestamp,
    };

    // Add message to sub-collection inside the chat room
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(messageData);
  }

  /// Streams messages in real-time for a specific chat room
  Stream<QuerySnapshot<Map<String, dynamic>>> getMessages(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }
}
