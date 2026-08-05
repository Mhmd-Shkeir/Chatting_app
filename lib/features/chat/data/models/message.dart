import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageStatus { sending, sent, delivered, read }

class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.status,
    this.timestamp,
  });

  final String id;
  final String senderId;
  final String text;
  final MessageStatus status;
  final DateTime? timestamp;

  factory Message.fromFirestore(Map<String, dynamic> data, String id) {
    return Message(
      id: id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      status: _statusFromString(data['status'] as String?),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }
}

MessageStatus _statusFromString(String? value) {
  switch (value) {
    case 'read':
      return MessageStatus.read;
    case 'delivered':
      return MessageStatus.delivered;
    case 'sending':
      return MessageStatus.sending;
    default:
      return MessageStatus.sent;
  }
}
