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

  /// Upgrades sent -> delivered for messages from [otherUid]. Called whenever
  /// this client observes the conversation update at all (not just when the
  /// chat screen is open), since "delivered" means the message reached this
  /// device — reusing the conversations stream that's already active for the
  /// whole session avoids standing up a separate background listener.
  Future<void> markMessagesDelivered({
    required String conversationId,
    required String otherUid,
  }) {
    return _updateMessagesFrom(
      conversationId: conversationId,
      otherUid: otherUid,
      matches: (status) => status == 'sent',
      newStatus: 'delivered',
    );
  }

  /// Upgrades sent/delivered -> read for messages from [otherUid]. Called
  /// only when the recipient actually opens this specific chat.
  Future<void> markMessagesRead({
    required String conversationId,
    required String otherUid,
  }) {
    return _updateMessagesFrom(
      conversationId: conversationId,
      otherUid: otherUid,
      matches: (status) => status != 'read',
      newStatus: 'read',
    );
  }

  Future<void> _updateMessagesFrom({
    required String conversationId,
    required String otherUid,
    required bool Function(String? status) matches,
    required String newStatus,
  }) async {
    final snapshot = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('senderId', isEqualTo: otherUid)
        .get();

    final pending = snapshot.docs.where((doc) => matches(doc.data()['status'] as String?));
    if (pending.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in pending) {
      batch.update(doc.reference, {'status': newStatus});
    }
    await batch.commit();
  }
}
