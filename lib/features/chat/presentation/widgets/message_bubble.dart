import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({required this.message, required this.isMine, super.key});

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final timestampColor =
        (isMine ? colorScheme.onPrimary : colorScheme.onSurface).withValues(alpha: 0.6);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMine ? colorScheme.primary : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isMine ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.timestamp != null)
                  Text(
                    DateFormat.jm().format(message.timestamp!),
                    style: TextStyle(fontSize: 11, color: timestampColor),
                  ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  _ReadReceipt(status: message.status, onPrimary: colorScheme.onPrimary),
                ],
              ],
            ),
          ],
        ),
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
    if (status == MessageStatus.sending) {
      return Icon(Icons.access_time, size: 14, color: onPrimary.withValues(alpha: 0.7));
    }

    final isRead = status == MessageStatus.read;
    final icon = status == MessageStatus.sent ? Icons.done : Icons.done_all;
    final color = isRead ? Colors.lightBlueAccent : onPrimary.withValues(alpha: 0.7);

    return Icon(icon, size: 14, color: color);
  }
}
