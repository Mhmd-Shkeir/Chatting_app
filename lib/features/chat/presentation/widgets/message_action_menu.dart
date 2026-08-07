import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/message.dart';
import '../providers/chat_providers.dart';

/// Quick-reaction choices shown at the top of the long-press menu. UI-only
/// for now — tapping one just closes the sheet. Wiring these to Firestore
/// (one reaction per user, tap again to remove/replace) is the next
/// roadmap item and slots in here without touching this row's layout.
const quickReactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

/// One row in the action list below the reaction row. [onTap] left null
/// renders the item disabled — that's how not-yet-implemented actions
/// (Edit, Delete, Forward, Message info) are represented until their own
/// feature work wires them up, without redesigning this menu.
class MessageActionItem {
  const MessageActionItem({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

/// Opens the Telegram-style long-press menu for [message]: a reaction row
/// up top, then the action list (Reply, Edit/Delete for own messages,
/// Forward, Copy for text messages, Message info).
Future<void> showMessageActionMenu(
  BuildContext context, {
  required WidgetRef ref,
  required Message message,
  required bool isMine,
}) {
  final actions = <MessageActionItem>[
    MessageActionItem(
      icon: Icons.reply,
      label: 'Reply',
      onTap: () => ref.read(replyingToProvider.notifier).set(message),
    ),
    if (isMine)
      const MessageActionItem(icon: Icons.edit_outlined, label: 'Edit'),
    if (isMine)
      const MessageActionItem(icon: Icons.delete_outline, label: 'Delete'),
    const MessageActionItem(icon: Icons.forward_outlined, label: 'Forward'),
    if (message.type == MessageType.text)
      MessageActionItem(
        icon: Icons.copy_outlined,
        label: 'Copy',
        onTap: () => Clipboard.setData(ClipboardData(text: message.text)),
      ),
    const MessageActionItem(icon: Icons.info_outline, label: 'Message info'),
  ];

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _MessageActionSheet(actions: actions),
  );
}

class _MessageActionSheet extends StatelessWidget {
  const _MessageActionSheet({required this.actions});

  final List<MessageActionItem> actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final emoji in quickReactionEmojis)
                  _ReactionButton(emoji: emoji),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final action in actions)
            ListTile(
              enabled: action.onTap != null,
              leading: Icon(action.icon),
              title: Text(action.label),
              onTap: action.onTap == null
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      action.onTap!();
                    },
            ),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({required this.emoji});

  final String emoji;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.of(context).pop(),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Text(emoji, style: const TextStyle(fontSize: 26)),
      ),
    );
  }
}
