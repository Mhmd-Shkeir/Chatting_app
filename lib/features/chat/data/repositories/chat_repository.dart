import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/message.dart';

class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<Message>> streamMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Message.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Message creation and conversation metadata (last message, unread count)
  /// are written as a single atomic batch, so a dropped connection between
  /// the two writes can never leave the message list and the conversation
  /// preview out of sync.
  Future<void> sendMessage({
    required String conversationId,
    required String recipientId,
    required String text,
  }) async {
    final senderId = _auth.currentUser!.uid;
    final conversationRef = _firestore.collection('conversations').doc(conversationId);
    final messageRef = conversationRef.collection('messages').doc();

    final batch = _firestore.batch();

    batch.set(messageRef, {
      'id': messageRef.id,
      'senderId': senderId,
      'text': text,
      'status': 'sent',
      'timestamp': FieldValue.serverTimestamp(),
    });

    batch.update(conversationRef, {
      'lastMessage': text,
      'lastMessageSenderId': senderId,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCounts.$recipientId': FieldValue.increment(1),
    });

    await batch.commit();
  }

  Future<void> markConversationRead(String conversationId) async {
    final myUid = _auth.currentUser!.uid;
    await _firestore.collection('conversations').doc(conversationId).update({
      'unreadCounts.$myUid': 0,
    });
  }
}
