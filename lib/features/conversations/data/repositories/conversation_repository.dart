import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/conversation.dart';

class ConversationRepository {
  ConversationRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<Conversation>> streamConversations(String uid) {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Conversation.fromFirestore(doc.data(), doc.id))
              // "Delete chat" from the list is really "clear it, but bring
              // it back the moment there's new activity" — so a
              // conversation stays hidden only while nothing has happened
              // since the clear.
              .where((conversation) {
                final clearedAt = conversation.clearedFor[uid];
                if (clearedAt == null) return true;
                final lastActivity = conversation.lastMessageTimestamp;
                return lastActivity != null && lastActivity.isAfter(clearedAt);
              })
              .toList(),
        );
  }

  /// Unfiltered, direct-by-ID lookup — deliberately separate from
  /// [streamConversations], which hides a conversation from the *list*
  /// after it's been cleared. A screen that's explicitly open on a known
  /// conversationId (chat screen, opening from search, etc.) must still
  /// resolve who the other participant is and be able to send to them
  /// regardless of list visibility — clearing a chat only affects the
  /// list/history, never the underlying conversation or the ability to
  /// message that person again.
  Stream<Conversation?> streamConversation(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .snapshots()
        .map(
          (doc) => doc.exists
              ? Conversation.fromFirestore(doc.data()!, doc.id)
              : null,
        );
  }

  /// Shared by "Clear chat" (inside a conversation) and "Delete chat"
  /// (from the conversation list) — same operation, just triggered from
  /// two different places. Per-uid, so it never touches the other
  /// participant's view of this conversation.
  Future<void> clearChatForMe(String conversationId) async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection('conversations').doc(conversationId).update({
      'clearedFor.$uid': FieldValue.serverTimestamp(),
    });
  }

  /// Conversation IDs are deterministic (sorted participant uids joined with
  /// `_`), so "does a conversation already exist between these two people"
  /// is a single document lookup instead of a query, and duplicate
  /// conversations between the same pair are structurally impossible.
  Future<String> getOrCreateConversation({
    required String otherUserId,
    required String otherUserDisplayName,
  }) async {
    final me = _auth.currentUser!;
    final participants = [me.uid, otherUserId]..sort();
    final conversationId = participants.join('_');
    final ref = _firestore.collection('conversations').doc(conversationId);

    final snapshot = await ref.get();
    if (!snapshot.exists) {
      await ref.set({
        'id': conversationId,
        'participants': participants,
        'participantNames': {
          me.uid: me.displayName ?? '',
          otherUserId: otherUserDisplayName,
        },
        'lastMessage': null,
        'lastMessageSenderId': null,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'unreadCounts': {for (final p in participants) p: 0},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return conversationId;
  }
}
