import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageStatus { sending, sent, delivered, read, failed }

enum MessageType { text, image }

class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.status,
    this.type = MessageType.text,
    this.imageUrl,
    this.timestamp,
  });

  final String id;
  final String senderId;
  final String text;
  final MessageStatus status;
  final MessageType type;
  final String? imageUrl;
  final DateTime? timestamp;

  factory Message.fromFirestore(Map<String, dynamic> data, String id) {
    return Message(
      id: id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      status: _statusFromString(data['status'] as String?),
      type: _typeFromString(data['type'] as String?),
      imageUrl: data['imageUrl'] as String?,
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
    case 'failed':
      return MessageStatus.failed;
    default:
      return MessageStatus.sent;
  }
}

MessageType _typeFromString(String? value) {
  switch (value) {
    case 'image':
      return MessageType.image;
    default:
      return MessageType.text;
  }
}
