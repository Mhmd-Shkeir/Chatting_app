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
    required List<String> recipientIds,
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
      for (final recipientId in recipientIds)
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
    required List<String> recipientIds,
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
      for (final recipientId in recipientIds)
        'unreadCounts.$recipientId': FieldValue.increment(1),
    });
    await batch.commit();
  }

  /// Mirrors [sendPendingImageMessage] for voice messages — a pending doc
  /// (status: sending, no audioUrl yet) so it's visible to both
  /// participants while the recording uploads. [durationSeconds] is
  /// captured client-side while recording and stored up front since it
  /// doesn't change once the upload completes.
  Future<String> sendPendingVoiceMessage(
    String conversationId, {
    required int durationSeconds,
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
      'type': 'voice',
      'audioUrl': null,
      'durationSeconds': durationSeconds,
      'status': 'sending',
      'timestamp': FieldValue.serverTimestamp(),
      if (replyTo != null) 'replyTo': replyTo.toMap(),
    });

    return messageRef.id;
  }

  /// Mirrors [completeImageMessage] for voice messages.
  Future<void> completeVoiceMessage({
    required String conversationId,
    required String messageId,
    required List<String> recipientIds,
    required String audioUrl,
  }) async {
    final senderId = _auth.currentUser!.uid;
    final conversationRef = _firestore
        .collection('conversations')
        .doc(conversationId);
    final messageRef = conversationRef.collection('messages').doc(messageId);

    final batch = _firestore.batch();
    batch.update(messageRef, {'audioUrl': audioUrl, 'status': 'sent'});
    batch.update(conversationRef, {
      'lastMessage': 'Voice message',
      'lastMessageSenderId': senderId,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      for (final recipientId in recipientIds)
        'unreadCounts.$recipientId': FieldValue.increment(1),
    });
    await batch.commit();
  }

  /// Mirrors [failImageMessage] for voice messages.
  Future<void> failVoiceMessage({
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

  /// Mirrors [retryImageMessage] for voice messages.
  Future<void> retryVoiceMessage({
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

  /// Sets the caller's reaction on a message, replacing any previous one —
  /// a dot-path update so it only ever touches the caller's own key in the
  /// `reactions` map (see firestore.rules), never anyone else's.
  Future<void> setReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    final uid = _auth.currentUser!.uid;
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'reactions.$uid': emoji});
  }

  /// Clears the caller's reaction on a message, if any.
  Future<void> removeReaction({
    required String conversationId,
    required String messageId,
  }) async {
    final uid = _auth.currentUser!.uid;
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'reactions.$uid': FieldValue.delete()});
  }

  /// Caches a translation of a message's original text under [languageCode]
  /// — shared cache, not per-user state, so any participant may write it
  /// (see firestore.rules); whoever views it first without a cached entry
  /// for their language pays the translation cost, everyone after reuses it.
  Future<void> setTranslation({
    required String conversationId,
    required String messageId,
    required String languageCode,
    required String translatedText,
  }) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'translations.$languageCode': translatedText});
  }

  /// Edits the sender's own text message. No edit history is kept — just
  /// the new text plus an `edited` flag for the bubble's indicator.
  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newText,
  }) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'text': newText, 'edited': true});
  }

  /// Sender-only: clears the message's content for every participant and
  /// flags it so bubbles render a placeholder instead. The doc itself is
  /// kept (not hard-deleted) — same reasoning as tombstoning a user doc:
  /// avoids needing a `delete` rule and keeps the surrounding messages'
  /// order/pagination untouched.
  Future<void> deleteMessageForEveryone({
    required String conversationId,
    required String messageId,
    required MessageType type,
  }) async {
    final updates = <String, Object?>{'deletedForEveryone': true, 'text': ''};
    if (type == MessageType.image) updates['imageUrl'] = null;
    if (type == MessageType.voice) updates['audioUrl'] = null;
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update(updates);
  }

  /// Removes the message from only the caller's own view — a dot-path
  /// write touching just their own key in `deletedFor`, same ownership
  /// shape as [setReaction]. The other participant keeps seeing it
  /// normally; the doc and its content are untouched.
  Future<void> deleteMessageForMe({
    required String conversationId,
    required String messageId,
  }) async {
    final uid = _auth.currentUser!.uid;
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'deletedFor.$uid': true});
  }

  /// Copies [message]'s content into a brand-new message doc in
  /// [targetConversationId] — no upload needed since image/voice URLs are
  /// already hosted; a reply/forward chain isn't preserved (matches most
  /// chat apps' "forward" semantics, as opposed to a reply).
  Future<void> forwardMessage({
    required String targetConversationId,
    required List<String> targetRecipientIds,
    required Message message,
  }) async {
    final senderId = _auth.currentUser!.uid;
    final conversationRef = _firestore
        .collection('conversations')
        .doc(targetConversationId);
    final messageRef = conversationRef.collection('messages').doc();

    final batch = _firestore.batch();
    batch.set(messageRef, {
      'id': messageRef.id,
      'senderId': senderId,
      'text': message.text,
      'type': switch (message.type) {
        MessageType.image => 'image',
        MessageType.voice => 'voice',
        MessageType.text => 'text',
      },
      if (message.imageUrl != null) 'imageUrl': message.imageUrl,
      if (message.audioUrl != null) 'audioUrl': message.audioUrl,
      if (message.durationSeconds != null)
        'durationSeconds': message.durationSeconds,
      'status': 'sent',
      'forwarded': true,
      'timestamp': FieldValue.serverTimestamp(),
    });
    batch.update(conversationRef, {
      'lastMessage': message.type == MessageType.text
          ? message.text
          : (message.type == MessageType.image ? 'Photo' : 'Voice message'),
      'lastMessageSenderId': senderId,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      for (final targetRecipientId in targetRecipientIds)
        'unreadCounts.$targetRecipientId': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> markConversationRead(String conversationId) async {
    final myUid = _auth.currentUser!.uid;
    await _firestore.collection('conversations').doc(conversationId).update({
      'unreadCounts.$myUid': 0,
    });
  }

  /// Upgrades sent -> delivered for every message not sent by [myUid] (i.e.
  /// from any other participant — one other person in a direct conversation,
  /// any number of them in a group). Called whenever this client observes
  /// the conversation update at all (not just when the chat screen is
  /// open), since "delivered" means the message reached this device —
  /// reusing the conversations stream that's already active for the whole
  /// session avoids standing up a separate background listener.
  Future<void> markMessagesDelivered({
    required String conversationId,
    required String myUid,
  }) {
    return _updateMessagesFrom(
      conversationId: conversationId,
      myUid: myUid,
      matches: (status) => status == 'sent',
      newStatus: 'delivered',
    );
  }

  /// Upgrades sent/delivered -> read for every message not sent by [myUid].
  /// Called only when the recipient actually opens this specific chat.
  Future<void> markMessagesRead({
    required String conversationId,
    required String myUid,
  }) {
    return _updateMessagesFrom(
      conversationId: conversationId,
      myUid: myUid,
      matches: (status) => status != 'read',
      newStatus: 'read',
    );
  }

  Future<void> _updateMessagesFrom({
    required String conversationId,
    required String myUid,
    required bool Function(String? status) matches,
    required String newStatus,
  }) async {
    final snapshot = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('senderId', isNotEqualTo: myUid)
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
