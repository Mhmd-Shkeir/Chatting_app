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
    this.replyTo,
  });

  final String id;
  final String senderId;
  final String text;
  final MessageStatus status;
  final MessageType type;
  final String? imageUrl;
  final DateTime? timestamp;
  final ReplyPreview? replyTo;

  factory Message.fromFirestore(Map<String, dynamic> data, String id) {
    final replyToData = data['replyTo'];
    return Message(
      id: id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      status: _statusFromString(data['status'] as String?),
      type: _typeFromString(data['type'] as String?),
      imageUrl: data['imageUrl'] as String?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      replyTo: replyToData is Map
          ? ReplyPreview.fromMap(Map<String, dynamic>.from(replyToData))
          : null,
    );
  }
}

/// A frozen snapshot of the message being replied to, stored inline on the
/// reply so the preview renders without a second read — same tradeoff as
/// `participantNames` on conversations. If the original message is later
/// deleted/edited, this preview intentionally stays as it was at reply time.
class ReplyPreview {
  const ReplyPreview({
    required this.messageId,
    required this.senderId,
    required this.text,
    required this.type,
  });

  final String messageId;
  final String senderId;
  final String text;
  final MessageType type;

  String get previewLabel => type == MessageType.image ? '📷 Photo' : text;

  factory ReplyPreview.fromMap(Map<String, dynamic> data) {
    return ReplyPreview(
      messageId: data['messageId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      type: _typeFromString(data['type'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
    'messageId': messageId,
    'senderId': senderId,
    'text': text,
    'type': type == MessageType.image ? 'image' : 'text',
  };

  factory ReplyPreview.fromMessage(Message message) {
    return ReplyPreview(
      messageId: message.id,
      senderId: message.senderId,
      text: message.type == MessageType.image ? '' : message.text,
      type: message.type,
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
