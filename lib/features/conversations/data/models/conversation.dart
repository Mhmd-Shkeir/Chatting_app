import 'package:cloud_firestore/cloud_firestore.dart';

enum ConversationType { direct, group }

class Conversation {
  const Conversation({
    required this.id,
    required this.participants,
    required this.participantNames,
    this.type = ConversationType.direct,
    this.groupName,
    this.groupAvatarUrl,
    this.admins = const [],
    this.createdBy,
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageTimestamp,
    this.unreadCounts = const {},
    this.createdAt,
    this.updatedAt,
    this.clearedFor = const {},
  });

  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;

  /// Missing on every conversation doc written before groups existed —
  /// defaults to [ConversationType.direct] so those docs stay valid
  /// untouched (see fromFirestore).
  final ConversationType type;

  /// Group-only fields; null for direct conversations.
  final String? groupName;
  final String? groupAvatarUrl;

  /// Just the creator for now — remove-member/rename/leave are deferred,
  /// but this field exists so those features have somewhere to go later.
  final List<String> admins;
  final String? createdBy;

  final String? lastMessage;
  final String? lastMessageSenderId;
  final DateTime? lastMessageTimestamp;
  final Map<String, int> unreadCounts;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isGroup => type == ConversationType.group;

  /// Uid -> when that participant last cleared this chat (from inside via
  /// "Clear chat" or from the conversation list via "Delete chat" — same
  /// underlying operation, see ConversationRepository.clearChatForMe).
  /// Messages/last-message-preview from before this timestamp are hidden
  /// from that uid only; new activity after it makes the conversation
  /// reappear in their list normally.
  final Map<String, DateTime> clearedFor;

  /// Direct conversations only — meaningless for a group, which has no
  /// single "other" participant. Callers must branch on [isGroup] first.
  String otherParticipantId(String myUid) {
    return participants.firstWhere((id) => id != myUid, orElse: () => myUid);
  }

  String otherParticipantName(String myUid) {
    return participantNames[otherParticipantId(myUid)] ?? 'Unknown';
  }

  /// Every participant except the caller — the group-safe generalization of
  /// [otherParticipantId], also valid (a single-element list) for direct
  /// conversations.
  List<String> otherParticipantIds(String myUid) {
    return participants.where((id) => id != myUid).toList();
  }

  /// What to show as this conversation's name from [myUid]'s point of view:
  /// the group's name for a group, otherwise the other person's name.
  String displayNameFor(String myUid) {
    return isGroup ? (groupName ?? 'Group') : otherParticipantName(myUid);
  }

  int unreadCountFor(String uid) => unreadCounts[uid] ?? 0;

  factory Conversation.fromFirestore(Map<String, dynamic> data, String id) {
    return Conversation(
      id: id,
      participants: List<String>.from(data['participants'] as List? ?? const []),
      participantNames: Map<String, String>.from(
        data['participantNames'] as Map? ?? const {},
      ),
      type: data['type'] == 'group' ? ConversationType.group : ConversationType.direct,
      groupName: data['groupName'] as String?,
      groupAvatarUrl: data['groupAvatarUrl'] as String?,
      admins: List<String>.from(data['admins'] as List? ?? const []),
      createdBy: data['createdBy'] as String?,
      lastMessage: data['lastMessage'] as String?,
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
      lastMessageTimestamp: (data['lastMessageTimestamp'] as Timestamp?)?.toDate(),
      unreadCounts: Map<String, int>.from(data['unreadCounts'] as Map? ?? const {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      clearedFor: (data['clearedFor'] as Map?)?.map(
            (key, value) =>
                MapEntry(key as String, (value as Timestamp).toDate()),
          ) ??
          const {},
    );
  }
}
