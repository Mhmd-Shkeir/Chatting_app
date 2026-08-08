import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  const Conversation({
    required this.id,
    required this.participants,
    required this.participantNames,
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
  final String? lastMessage;
  final String? lastMessageSenderId;
  final DateTime? lastMessageTimestamp;
  final Map<String, int> unreadCounts;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Uid -> when that participant last cleared this chat (from inside via
  /// "Clear chat" or from the conversation list via "Delete chat" — same
  /// underlying operation, see ConversationRepository.clearChatForMe).
  /// Messages/last-message-preview from before this timestamp are hidden
  /// from that uid only; new activity after it makes the conversation
  /// reappear in their list normally.
  final Map<String, DateTime> clearedFor;

  String otherParticipantId(String myUid) {
    return participants.firstWhere((id) => id != myUid, orElse: () => myUid);
  }

  String otherParticipantName(String myUid) {
    return participantNames[otherParticipantId(myUid)] ?? 'Unknown';
  }

  int unreadCountFor(String uid) => unreadCounts[uid] ?? 0;

  factory Conversation.fromFirestore(Map<String, dynamic> data, String id) {
    return Conversation(
      id: id,
      participants: List<String>.from(data['participants'] as List? ?? const []),
      participantNames: Map<String, String>.from(
        data['participantNames'] as Map? ?? const {},
      ),
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
