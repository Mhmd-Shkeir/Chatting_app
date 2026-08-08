import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/message.dart';
import '../providers/chat_providers.dart';
import '../screens/image_viewer_screen.dart';
import 'message_action_menu.dart';
import 'reply_preview_strip.dart';
import 'swipe_to_reply.dart';

class MessageBubble extends ConsumerWidget {
  const MessageBubble({
    required this.message,
    required this.isMine,
    required this.conversationId,
    required this.recipientId,
    required this.currentUserId,
    required this.otherUserName,
    this.onReplyTap,
    this.onEdit,
    this.isHighlighted = false,
    this.translateToLanguageCode,
    super.key,
  });

  final Message message;
  final bool isMine;
  final String conversationId;
  final String recipientId;
  final String currentUserId;
  final String otherUserName;
  final ValueChanged<String>? onReplyTap;
  final ValueChanged<Message>? onEdit;
  final bool isHighlighted;

  /// Non-null when the viewer's preferred language differs from the
  /// sender's — see ChatScreen._translationTarget. Only applied to
  /// messages that aren't mine; translating your own sent text back to
  /// yourself makes no sense.
  final String? translateToLanguageCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isImage = message.type == MessageType.image;
    final isVoice = message.type == MessageType.voice;
    final replyTo = message.replyTo;
    final needsTranslation =
        !isMine && !isImage && !isVoice && translateToLanguageCode != null;

    final timestampColor =
        (isMine ? colorScheme.onPrimary : colorScheme.onSurface).withValues(
          alpha: 0.6,
        );

    final baseColor = isMine
        ? colorScheme.primary
        : colorScheme.surfaceContainer;
    final bubbleColor = isHighlighted
        ? Color.alphaBlend(
            colorScheme.tertiary.withValues(alpha: 0.45),
            baseColor,
          )
        : baseColor;

    return SwipeToReply(
      onReply: () => ref.read(replyingToProvider.notifier).set(message),
      onLongPress: message.deletedForEveryone
          ? null
          : () => showMessageActionMenu(
              context,
              ref: ref,
              conversationId: conversationId,
              message: message,
              isMine: isMine,
              currentUserId: currentUserId,
              onEdit: onEdit,
            ),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: isImage
                  ? const EdgeInsets.all(4)
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (replyTo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ReplyPreviewStrip(
                        senderLabel: replyTo.senderId == currentUserId
                            ? 'You'
                            : otherUserName,
                        preview: replyTo.previewLabel,
                        onTap: onReplyTap == null
                            ? null
                            : () => onReplyTap!(replyTo.messageId),
                        backgroundColor:
                            (isMine
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface)
                                .withValues(alpha: 0.08),
                        accentColor: isMine
                            ? colorScheme.onPrimary
                            : colorScheme.primary,
                        foregroundColor: isMine
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                      ),
                    ),
                  if (message.forwarded && !message.deletedForEveryone)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Forwarded',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: timestampColor,
                        ),
                      ),
                    ),
                  if (message.deletedForEveryone)
                    Text(
                      isMine
                          ? 'You deleted this message'
                          : 'This message was deleted',
                      style: TextStyle(
                        color: timestampColor,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else if (isImage)
                    _ImageContent(
                      message: message,
                      isMine: isMine,
                      conversationId: conversationId,
                      recipientId: recipientId,
                      ref: ref,
                    )
                  else if (isVoice)
                    _VoiceContent(
                      message: message,
                      isMine: isMine,
                      conversationId: conversationId,
                      recipientId: recipientId,
                      textColor: isMine
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                      ref: ref,
                    )
                  else if (needsTranslation)
                    _TranslatableText(
                      message: message,
                      conversationId: conversationId,
                      targetLanguageCode: translateToLanguageCode!,
                      textColor: colorScheme.onSurface,
                    )
                  else
                    Text(
                      message.text,
                      style: TextStyle(
                        color: isMine
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: isImage
                        ? const EdgeInsets.only(right: 4)
                        : EdgeInsets.zero,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.edited && !message.deletedForEveryone) ...[
                          Text(
                            'edited',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: timestampColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (message.timestamp != null)
                          Text(
                            DateFormat.jm().format(message.timestamp!),
                            style: TextStyle(
                              fontSize: 11,
                              color: timestampColor,
                            ),
                          ),
                        if (isMine) ...[
                          const SizedBox(width: 4),
                          _ReadReceipt(
                            status: message.status,
                            onPrimary: colorScheme.onPrimary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (message.reactions.isNotEmpty && !message.deletedForEveryone)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _ReactionsRow(
                  message: message,
                  conversationId: conversationId,
                  currentUserId: currentUserId,
                  ref: ref,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({
    required this.message,
    required this.isMine,
    required this.conversationId,
    required this.recipientId,
    required this.ref,
  });

  final Message message;
  final bool isMine;
  final String conversationId;
  final String recipientId;
  final WidgetRef ref;

  static const double _size = 220;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final localFile = ref.watch(pendingImageFilesProvider).get(message.id);

    if (message.status == MessageStatus.failed) {
      return GestureDetector(
        onTap: isMine
            ? () => ref
                  .read(sendImageMessageControllerProvider.notifier)
                  .retry(
                    conversationId: conversationId,
                    recipientId: recipientId,
                    messageId: message.id,
                  )
            : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: _size,
            height: _size,
            color: colorScheme.errorContainer,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (localFile != null)
                  Opacity(
                    opacity: 0.4,
                    child: Image.file(localFile, fit: BoxFit.cover),
                  ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, color: colorScheme.onErrorContainer),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to retry',
                        style: TextStyle(
                          color: colorScheme.onErrorContainer,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final imageUrl = message.imageUrl;

    return GestureDetector(
      onTap: imageUrl != null
          ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ImageViewerScreen(imageUrl: imageUrl),
              ),
            )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: _size,
          height: _size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _pendingPreview(localFile),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.broken_image_outlined, size: 32),
                )
              else
                _pendingPreview(localFile),
              if (message.status == MessageStatus.sending)
                const ColoredBox(
                  color: Colors.black26,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pendingPreview(File? localFile) {
    if (localFile != null) {
      return Image.file(localFile, fit: BoxFit.cover);
    }
    return const ColoredBox(color: Colors.black26);
  }
}

/// Play/pause + progress for a voice message, or a "Tap to retry" state
/// while the upload is still pending/failed — mirrors [_ImageContent]'s
/// failed-state handling but for audio.
class _VoiceContent extends StatefulWidget {
  const _VoiceContent({
    required this.message,
    required this.isMine,
    required this.conversationId,
    required this.recipientId,
    required this.textColor,
    required this.ref,
  });

  final Message message;
  final bool isMine;
  final String conversationId;
  final String recipientId;
  final Color textColor;
  final WidgetRef ref;

  @override
  State<_VoiceContent> createState() => _VoiceContentState();
}

class _VoiceContentState extends State<_VoiceContent> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration? _duration;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
    _player.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration);
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final audioUrl = widget.message.audioUrl;
    if (audioUrl == null) return;
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(audioUrl));
    }
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.status == MessageStatus.failed) {
      return GestureDetector(
        onTap: widget.isMine
            ? () => widget.ref
                  .read(sendVoiceMessageControllerProvider.notifier)
                  .retry(
                    conversationId: widget.conversationId,
                    recipientId: widget.recipientId,
                    messageId: widget.message.id,
                  )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh, color: widget.textColor),
            const SizedBox(width: 8),
            Text('Voice message failed · Tap to retry',
                style: TextStyle(color: widget.textColor, fontSize: 13)),
          ],
        ),
      );
    }

    if (widget.message.status == MessageStatus.sending) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.textColor,
            ),
          ),
          const SizedBox(width: 8),
          Text('Sending voice message…',
              style: TextStyle(color: widget.textColor, fontSize: 13)),
        ],
      );
    }

    final total =
        _duration ??
        Duration(seconds: widget.message.durationSeconds ?? 0);
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return SizedBox(
      width: 180,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: _togglePlayback,
            child: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: widget.textColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: widget.textColor.withValues(alpha: 0.25),
                    valueColor: AlwaysStoppedAnimation(widget.textColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isPlaying || _position > Duration.zero
                      ? _format(_position)
                      : _format(total),
                  style: TextStyle(
                    color: widget.textColor.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadReceipt extends StatelessWidget {
  const _ReadReceipt({required this.status, required this.onPrimary});

  final MessageStatus status;
  final Color onPrimary;

  @override
  Widget build(BuildContext context) {
    if (status == MessageStatus.failed) {
      return Icon(
        Icons.error_outline,
        size: 14,
        color: Theme.of(context).colorScheme.error,
      );
    }
    if (status == MessageStatus.sending) {
      return Icon(
        Icons.access_time,
        size: 14,
        color: onPrimary.withValues(alpha: 0.7),
      );
    }

    final isRead = status == MessageStatus.read;
    final icon = status == MessageStatus.sent ? Icons.done : Icons.done_all;
    final color = isRead
        ? Colors.lightBlueAccent
        : onPrimary.withValues(alpha: 0.7);

    return Icon(icon, size: 14, color: color);
  }
}

/// Grouped reaction pills shown under a bubble once it has at least one
/// reaction — e.g. "👍 2". Tapping a pill toggles the current user's own
/// reaction the same way the long-press menu's reaction row does.
class _ReactionsRow extends StatelessWidget {
  const _ReactionsRow({
    required this.message,
    required this.conversationId,
    required this.currentUserId,
    required this.ref,
  });

  final Message message;
  final String conversationId;
  final String currentUserId;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final emoji in message.reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    final myReaction = message.reactions[currentUserId];

    return Wrap(
      spacing: 4,
      children: [
        for (final entry in counts.entries)
          _ReactionBadge(
            emoji: entry.key,
            count: entry.value,
            isMine: entry.key == myReaction,
            onTap: () {
              final chatRepository = ref.read(chatRepositoryProvider);
              if (entry.key == myReaction) {
                chatRepository.removeReaction(
                  conversationId: conversationId,
                  messageId: message.id,
                );
              } else {
                chatRepository.setReaction(
                  conversationId: conversationId,
                  messageId: message.id,
                  emoji: entry.key,
                );
              }
            },
          ),
      ],
    );
  }
}

class _ReactionBadge extends StatelessWidget {
  const _ReactionBadge({
    required this.emoji,
    required this.count,
    required this.isMine,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool isMine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isMine
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: isMine
              ? Border.all(color: colorScheme.primary, width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            if (count > 1) ...[
              const SizedBox(width: 3),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders the original text plus a tappable "Translate" label — the
/// translation is only fetched (via translationTriggerProvider) when the
/// user actually taps it, never automatically. Opening a chat full of
/// foreign-language messages must not fan out a translation call per
/// message at once; Gemini's free tier only allows a handful of calls a
/// day, so every one of them has to be a deliberate user action. Once
/// translated, the live message stream swaps [message.translations] in and
/// this flips to the same "Translated · Show original" toggle as before.
class _TranslatableText extends ConsumerStatefulWidget {
  const _TranslatableText({
    required this.message,
    required this.conversationId,
    required this.targetLanguageCode,
    required this.textColor,
  });

  final Message message;
  final String conversationId;
  final String targetLanguageCode;
  final Color textColor;

  @override
  ConsumerState<_TranslatableText> createState() => _TranslatableTextState();
}

class _TranslatableTextState extends ConsumerState<_TranslatableText> {
  bool _isTranslating = false;
  bool _showOriginal = false;
  bool _failed = false;

  Future<void> _translate() async {
    setState(() {
      _isTranslating = true;
      _failed = false;
    });
    try {
      await ref.read(
        translationTriggerProvider((
          conversationId: widget.conversationId,
          messageId: widget.message.id,
          text: widget.message.text,
          targetLanguageCode: widget.targetLanguageCode,
        )).future,
      );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final translated = widget.message.translations[widget.targetLanguageCode];
    final showingOriginal = translated == null || _showOriginal;
    final labelStyle = TextStyle(
      fontSize: 11,
      fontStyle: FontStyle.italic,
      color: widget.textColor.withValues(alpha: 0.7),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          showingOriginal ? widget.message.text : translated,
          style: TextStyle(color: widget.textColor),
        ),
        if (translated != null)
          GestureDetector(
            onTap: () => setState(() => _showOriginal = !_showOriginal),
            child: Text(
              _showOriginal ? 'Show translation' : 'Translated · Show original',
              style: labelStyle,
            ),
          )
        else
          GestureDetector(
            onTap: _isTranslating ? null : _translate,
            child: Text(
              _failed
                  ? 'Translation failed · Tap to retry'
                  : (_isTranslating ? 'Translating…' : 'Translate'),
              style: labelStyle,
            ),
          ),
      ],
    );
  }
}
