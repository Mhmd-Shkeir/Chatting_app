import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/conversation.dart';

class ConversationRepository {
  ConversationRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Basic E2EE MVP toggle (1:1 conversations only) — either participant
  /// can turn it on; once set, new outgoing text messages get encrypted.
  /// No rules change needed (the conversation `update` rule is already
  /// permissive to any current participant, same as clearedFor/mentionedUnread).
  Future<void> setE2eeEnabled(String conversationId, bool enabled) {
    return _firestore.collection('conversations').doc(conversationId).update({
      'e2eeEnabled': enabled,
    });
  }

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

  /// Group conversations can't reuse the deterministic sorted-uids ID
  /// scheme above — membership changes over time, so there's no fixed key
  /// to derive it from. Gets a fresh auto-generated doc ID instead.
  /// [memberNames] is uid -> display name for every member other than the
  /// creator, mirroring participantNames' shape.
  Future<String> createGroup({
    required String name,
    String? avatarUrl,
    required Map<String, String> memberNames,
  }) async {
    final me = _auth.currentUser!;
    final ref = _firestore.collection('conversations').doc();
    final participants = <String>{me.uid, ...memberNames.keys}.toList();
    final participantNames = {
      me.uid: me.displayName ?? '',
      ...memberNames,
    };

    await ref.set({
      'id': ref.id,
      'type': 'group',
      'groupName': name,
      'groupAvatarUrl': avatarUrl,
      'admins': [me.uid],
      'createdBy': me.uid,
      'participants': participants,
      'participantNames': participantNames,
      'lastMessage': null,
      'lastMessageSenderId': null,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'unreadCounts': {for (final p in participants) p: 0},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  /// Adds members to an existing group — dot-path writes to
  /// participantNames/unreadCounts plus an arrayUnion on participants, same
  /// ownership shape as the rest of this app's per-uid map updates (see
  /// setReaction/deleteMessageForMe). Covered by the existing permissive
  /// conversation-update rule (any current participant may update), no
  /// rules change needed.
  Future<void> addMembers({
    required String conversationId,
    required Map<String, String> memberNames,
  }) async {
    final updates = <String, Object?>{
      'participants': FieldValue.arrayUnion(memberNames.keys.toList()),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    for (final entry in memberNames.entries) {
      updates['participantNames.${entry.key}'] = entry.value;
      updates['unreadCounts.${entry.key}'] = 0;
    }
    await _firestore.collection('conversations').doc(conversationId).update(updates);
  }

  /// Removes [uid] from a group's participants (and, if present, admins) —
  /// gated to admins in the UI (see GroupInfoScreen); enforcement stops at
  /// the client, same as every other field on this doc (the conversation
  /// `update` rule stays permissive for any current participant). Also
  /// used by [leaveGroup], which just targets the caller.
  Future<void> removeMember({
    required String conversationId,
    required String uid,
  }) async {
    await _firestore.collection('conversations').doc(conversationId).update({
      'participants': FieldValue.arrayRemove([uid]),
      'admins': FieldValue.arrayRemove([uid]),
      'participantNames.$uid': FieldValue.delete(),
      'unreadCounts.$uid': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Removes the caller from a group — available to any member, including
  /// the creator. If the creator leaves, the group is left with no admins
  /// (promoting a replacement admin is deferred, same as the rest of the
  /// admin feature set).
  Future<void> leaveGroup(String conversationId) {
    final uid = _auth.currentUser!.uid;
    return removeMember(conversationId: conversationId, uid: uid);
  }
}
