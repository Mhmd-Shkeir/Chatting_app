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
    ReplyPreview? replyTo,
  }) async {
    final senderId = _auth.currentUser!.uid;
    final conversationRef = _firestore
        .collection('conversations')
        .doc(conversationId);
    final messageRef = conversationRef.collection('messages').doc();

    final batch = _firestore.batch();

    batch.set(messageRef, {
      'id': messageRef.id,
      'senderId': senderId,
      'text': text,
      'status': 'sent',
      'timestamp': FieldValue.serverTimestamp(),
      if (replyTo != null) 'replyTo': replyTo.toMap(),
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

  /// Creates a pending image-message doc immediately (status: sending, no
  /// imageUrl yet) so it appears live for both participants — including the
  /// recipient, via the same real-time listener — while the upload is still
  /// in flight, rather than making everyone wait for the whole round trip.
  /// Returns the new message id so the caller can complete or fail it once
  /// the upload settles.
  Future<String> sendPendingImageMessage(
    String conversationId, {
    ReplyPreview? replyTo,
  }) async {
    final senderId = _auth.currentUser!.uid;
    final messageRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc();

    await messageRef.set({
      'id': messageRef.id,
      'senderId': senderId,
      'text': '',
      'type': 'image',
      'imageUrl': null,
      'status': 'sending',
      'timestamp': FieldValue.serverTimestamp(),
      if (replyTo != null) 'replyTo': replyTo.toMap(),
    });

    return messageRef.id;
  }

  /// Finishes a pending image message once its upload succeeds: fills in
  /// the real URL, flips status to sent, and updates the conversation
  /// preview — mirroring what [sendMessage] does for text in one batch,
  /// just as a second write here since the upload sits in between the two.
  Future<void> completeImageMessage({
    required String conversationId,
    required String messageId,
    required String recipientId,
    required String imageUrl,
  }) async {
    final senderId = _auth.currentUser!.uid;
    final conversationRef = _firestore
        .collection('conversations')
        .doc(conversationId);
    final messageRef = conversationRef.collection('messages').doc(messageId);

    final batch = _firestore.batch();
    batch.update(messageRef, {'imageUrl': imageUrl, 'status': 'sent'});
    batch.update(conversationRef, {
      'lastMessage': 'Photo',
      'lastMessageSenderId': senderId,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCounts.$recipientId': FieldValue.increment(1),
    });
    await batch.commit();
  }

  /// Marks a pending (or previously failed, on a retry that failed again)
  /// image message as failed, so the sender's own bubble can offer a retry
  /// instead of spinning forever.
  Future<void> failImageMessage({
    required String conversationId,
    required String messageId,
  }) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'status': 'failed'});
  }

  /// Puts a failed image message back into the sending state for a retry
  /// attempt — a separate step from actually re-uploading, so the bubble
  /// can show the spinner again immediately rather than waiting on the
  /// upload's first byte.
  Future<void> retryImageMessage({
    required String conversationId,
    required String messageId,
  }) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'status': 'sending'});
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

    final pending = snapshot.docs.where(
      (doc) => matches(doc.data()['status'] as String?),
    );
    if (pending.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in pending) {
      batch.update(doc.reference, {'status': newStatus});
    }
    await batch.commit();
  }
}
