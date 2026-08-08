import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/message.dart';
import '../providers/chat_providers.dart';
import 'forward_message_sheet.dart';

/// Quick-reaction choices shown at the top of the long-press menu. Adding
/// another emoji later is just extending this list — the row, the
/// highlight-if-mine styling, and the Firestore toggle logic all key off
/// it generically.
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
  required String conversationId,
  required Message message,
  required bool isMine,
  required String currentUserId,
  ValueChanged<Message>? onEdit,
}) {
  final actions = <MessageActionItem>[
    MessageActionItem(
      icon: Icons.reply,
      label: 'Reply',
      onTap: () => ref.read(replyingToProvider.notifier).set(message),
    ),
    if (isMine && message.type == MessageType.text && onEdit != null)
      MessageActionItem(
        icon: Icons.edit_outlined,
        label: 'Edit',
        onTap: () => onEdit(message),
      ),
    MessageActionItem(
      icon: Icons.delete_outline,
      label: 'Delete',
      onTap: () => _showDeleteChoices(
        context,
        ref: ref,
        conversationId: conversationId,
        message: message,
        isMine: isMine,
      ),
    ),
    MessageActionItem(
      icon: Icons.forward_outlined,
      label: 'Forward',
      onTap: () => showForwardMessageSheet(context, ref: ref, message: message),
    ),
    if (message.type == MessageType.text)
      MessageActionItem(
        icon: Icons.copy_outlined,
        label: 'Copy',
        onTap: () => Clipboard.setData(ClipboardData(text: message.text)),
      ),
    const MessageActionItem(icon: Icons.info_outline, label: 'Message info'),
  ];

  final myReaction = message.reactions[currentUserId];

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _MessageActionSheet(
      actions: actions,
      myReaction: myReaction,
      onSelectReaction: (emoji) {
        final chatRepository = ref.read(chatRepositoryProvider);
        if (emoji == myReaction) {
          chatRepository.removeReaction(
            conversationId: conversationId,
            messageId: message.id,
          );
        } else {
          chatRepository.setReaction(
            conversationId: conversationId,
            messageId: message.id,
            emoji: emoji,
          );
        }
      },
    ),
  );
}

/// "Delete for me" (always available) vs "Delete for everyone" (sender
/// only) — shown as a second, focused sheet rather than cramming both
/// choices into the main action list.
void _showDeleteChoices(
  BuildContext context, {
  required WidgetRef ref,
  required String conversationId,
  required Message message,
  required bool isMine,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.person_remove_outlined),
            title: const Text('Delete for me'),
            onTap: () {
              Navigator.of(context).pop();
              ref.read(chatRepositoryProvider).deleteMessageForMe(
                    conversationId: conversationId,
                    messageId: message.id,
                  );
            },
          ),
          if (isMine)
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: const Text('Delete for everyone'),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(chatRepositoryProvider).deleteMessageForEveryone(
                      conversationId: conversationId,
                      messageId: message.id,
                      type: message.type,
                    );
              },
            ),
        ],
      ),
    ),
  );
}

class _MessageActionSheet extends StatelessWidget {
  const _MessageActionSheet({
    required this.actions,
    required this.myReaction,
    required this.onSelectReaction,
  });

  final List<MessageActionItem> actions;
  final String? myReaction;
  final ValueChanged<String> onSelectReaction;

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
                  _ReactionButton(
                    emoji: emoji,
                    selected: emoji == myReaction,
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelectReaction(emoji);
                    },
                  ),
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
  const _ReactionButton({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        decoration: selected
            ? BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              )
            : null,
        padding: const EdgeInsets.all(6),
        child: Text(emoji, style: const TextStyle(fontSize: 26)),
      ),
    );
  }
}
