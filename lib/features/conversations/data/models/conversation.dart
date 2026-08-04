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
    );
  }
}
