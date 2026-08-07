import 'package:flutter/material.dart';

/// A small quoted-message strip. Used both above the compose bar (with a
/// cancel button, while composing a reply) and inside a bubble (tappable,
/// to jump back to the original message).
class ReplyPreviewStrip extends StatelessWidget {
  const ReplyPreviewStrip({
    required this.senderLabel,
    required this.preview,
    this.onTap,
    this.onCancel,
    this.accentColor,
    this.backgroundColor,
    this.foregroundColor,
    super.key,
  });

  final String senderLabel;
  final String preview;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;
  final Color? accentColor;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = accentColor ?? colorScheme.primary;
    final foreground = foregroundColor ?? colorScheme.onSurface;

    final content = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  senderLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: accent,
                  ),
                ),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: foreground.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          if (onCancel != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: onCancel,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: foreground,
            ),
        ],
      ),
    );

    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}
