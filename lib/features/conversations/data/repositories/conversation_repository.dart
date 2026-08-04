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
              .toList(),
        );
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
