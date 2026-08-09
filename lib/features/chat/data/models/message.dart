import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/firestore_timestamp_map.dart';

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
    this.edited = false,
    this.deletedForEveryone = false,
    this.deletedFor = const {},
    this.forwarded = false,
    this.mentions = const [],
    this.encrypted = false,
    this.readBy = const {},
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

  /// Text messages only — set when the sender edits their own message
  /// after sending. The original text is intentionally not preserved
  /// anywhere (no edit history), matching the roadmap's "preserve if
  /// needed" note interpreted as not required for this app.
  final bool edited;

  /// Sender deleted this for every participant — content is cleared
  /// (`text`/`imageUrl`/`audioUrl`) and the bubble renders a placeholder
  /// instead. Distinct from [deletedFor], which is per-viewer.
  final bool deletedForEveryone;

  /// Uid -> true for participants who deleted this message "for me" —
  /// mirrors [reactions]' per-user-key shape. The message doc still
  /// exists (still visible/editable by others); ChatScreen filters it out
  /// of the list for uids present here.
  final Map<String, bool> deletedFor;

  /// Set on the new message doc created by forwarding — shown as a small
  /// "Forwarded" label, distinct from a reply (no link back to the
  /// original message/conversation).
  final bool forwarded;

  /// Uids of participants explicitly @mentioned when this message was
  /// composed (see ChatScreen's @-trigger autocomplete). Group chats only
  /// — a direct conversation has nobody else to disambiguate. Immutable
  /// once sent, same as the text itself.
  final List<String> mentions;

  /// True for a Basic E2EE MVP message (1:1 text only — see
  /// E2eeRepository) — when set, [text] holds an encrypted blob, not
  /// readable content, and callers must decrypt it before display (see
  /// MessageBubble's _EncryptedText). Immutable once sent.
  final bool encrypted;

  /// Uid -> when that participant read this message — per-recipient,
  /// unlike [status] (a single shared value). A direct conversation's
  /// single recipient reading it is equivalent to the old status=='read'
  /// behavior; a group message needs every other participant's key
  /// present before it counts as fully read (see [isReadByAll]) — one
  /// member opening the chat shouldn't turn the tick blue for everyone.
  final Map<String, DateTime> readBy;

  /// The "double blue tick" condition: every uid in [recipientIds] (every
  /// other participant — one for a direct conversation, all members for a
  /// group) has read this message. Falls back to the legacy shared
  /// [status] for messages written before per-recipient tracking existed
  /// (which never had readBy entries), so old direct-chat history doesn't
  /// visually regress from blue back to gray.
  bool isReadByAll(Iterable<String> recipientIds) {
    final ids = recipientIds.toList();
    if (ids.isEmpty) return false;
    return ids.every(readBy.containsKey) || status == MessageStatus.read;
  }

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
      edited: data['edited'] as bool? ?? false,
      deletedForEveryone: data['deletedForEveryone'] as bool? ?? false,
      deletedFor: data['deletedFor'] is Map
          ? Map<String, bool>.from(data['deletedFor'] as Map)
          : const {},
      forwarded: data['forwarded'] as bool? ?? false,
      mentions: data['mentions'] is List
          ? List<String>.from(data['mentions'] as List)
          : const [],
      encrypted: data['encrypted'] as bool? ?? false,
      readBy: timestampMapFrom(data['readBy']),
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
      // An encrypted message's own `text` is ciphertext — never copy it
      // into a reply preview (a plaintext-adjacent Firestore field the
      // server can read). A fixed label instead; reply still links back to
      // the right message, it just can't show a snippet.
      text: message.encrypted
          ? '🔒 Encrypted message'
          : (message.type == MessageType.image ? '' : message.text),
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
