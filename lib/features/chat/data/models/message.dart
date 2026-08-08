import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageStatus { sending, sent, delivered, read, failed }

enum MessageType { text, image, voice }

class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.status,
    this.type = MessageType.text,
    this.imageUrl,
    this.audioUrl,
    this.durationSeconds,
    this.timestamp,
    this.replyTo,
    this.reactions = const {},
    this.translations = const {},
  });

  final String id;
  final String senderId;
  final String text;
  final MessageStatus status;
  final MessageType type;
  final String? imageUrl;

  /// Only set for [MessageType.voice] — the ImageKit CDN URL for the
  /// recorded audio file (ImageKit's upload API is generic, not
  /// image-only, despite the class name).
  final String? audioUrl;

  /// Only set for [MessageType.voice] — captured client-side while
  /// recording, since neither `record` nor the file itself expose it
  /// directly without decoding the audio.
  final int? durationSeconds;

  final DateTime? timestamp;
  final ReplyPreview? replyTo;

  /// Uid -> emoji, one entry per user who reacted (at most one reaction each).
  final Map<String, String> reactions;

  /// Language code -> translated text, populated lazily the first time
  /// someone whose preferred language differs from the sender's views this
  /// message, and cached here so later views (any participant, any device)
  /// don't re-call the translation API. [text] itself is never overwritten.
  final Map<String, String> translations;

  factory Message.fromFirestore(Map<String, dynamic> data, String id) {
    final replyToData = data['replyTo'];
    final reactionsData = data['reactions'];
    final translationsData = data['translations'];
    return Message(
      id: id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      status: _statusFromString(data['status'] as String?),
      type: _typeFromString(data['type'] as String?),
      imageUrl: data['imageUrl'] as String?,
      audioUrl: data['audioUrl'] as String?,
      durationSeconds: data['durationSeconds'] as int?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      replyTo: replyToData is Map
          ? ReplyPreview.fromMap(Map<String, dynamic>.from(replyToData))
          : null,
      reactions: reactionsData is Map
          ? Map<String, String>.from(reactionsData)
          : const {},
      translations: translationsData is Map
          ? Map<String, String>.from(translationsData)
          : const {},
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

  String get previewLabel => switch (type) {
    MessageType.image => '📷 Photo',
    MessageType.voice => '🎤 Voice message',
    MessageType.text => text,
  };

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
    'type': switch (type) {
      MessageType.image => 'image',
      MessageType.voice => 'voice',
      MessageType.text => 'text',
    },
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
    case 'voice':
      return MessageType.voice;
    default:
      return MessageType.text;
  }
}
