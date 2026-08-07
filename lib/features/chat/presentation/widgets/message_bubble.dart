import 'dart:io';

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
    this.isHighlighted = false,
    super.key,
  });

  final Message message;
  final bool isMine;
  final String conversationId;
  final String recipientId;
  final String currentUserId;
  final String otherUserName;
  final ValueChanged<String>? onReplyTap;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isImage = message.type == MessageType.image;
    final replyTo = message.replyTo;

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
      onLongPress: () => showMessageActionMenu(
        context,
        ref: ref,
        message: message,
        isMine: isMine,
      ),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: AnimatedContainer(
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
                        (isMine ? colorScheme.onPrimary : colorScheme.onSurface)
                            .withValues(alpha: 0.08),
                    accentColor: isMine
                        ? colorScheme.onPrimary
                        : colorScheme.primary,
                    foregroundColor: isMine
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                  ),
                ),
              if (isImage)
                _ImageContent(
                  message: message,
                  isMine: isMine,
                  conversationId: conversationId,
                  recipientId: recipientId,
                  ref: ref,
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
                    if (message.timestamp != null)
                      Text(
                        DateFormat.jm().format(message.timestamp!),
                        style: TextStyle(fontSize: 11, color: timestampColor),
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
