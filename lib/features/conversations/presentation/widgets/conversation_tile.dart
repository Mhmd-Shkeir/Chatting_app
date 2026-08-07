import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/conversation_timestamp_formatter.dart';
import '../../../authentication/presentation/providers/presence_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/models/conversation.dart';

class ConversationTile extends ConsumerWidget {
  const ConversationTile({
    required this.conversation,
    required this.myUid,
    required this.onTap,
    super.key,
  });

  final Conversation conversation;
  final String myUid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = conversation.unreadCountFor(myUid);
    final otherUid = conversation.otherParticipantId(myUid);
    final otherProfile = ref.watch(userProfileProvider(otherUid)).value;
    // participantNames is a frozen snapshot from when the conversation was
    // created (see conversation_repository.dart) — it never learns that
    // the other person deleted their account, so that has to come from
    // the same live per-uid lookup already used for @username.
    final isDeleted = otherProfile?.deleted ?? false;
    final name = isDeleted ? 'Deleted Account' : conversation.otherParticipantName(myUid);
    // A deleted account must never show as online — gated ahead of the
    // watch itself, not just the rendering below, so a deleted account is
    // never presence-listened-to in the first place.
    final isOnline =
        isDeleted ? false : ref.watch(presenceStatusProvider(otherUid)).value?.isOnline ?? false;
    final username = otherProfile?.username;
    final colorScheme = Theme.of(context).colorScheme;
    final hasUnread = unread > 0;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (isOnline)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
          if (username != null && username.isNotEmpty) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '@$username',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        conversation.lastMessage ?? 'Say hello',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: hasUnread ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatConversationTimestamp(conversation.lastMessageTimestamp),
            style: TextStyle(
              fontSize: 12,
              color: hasUnread ? colorScheme.primary : colorScheme.onSurfaceVariant,
              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          if (hasUnread)
            Container(
              constraints: const BoxConstraints(minWidth: 20),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onPrimary,
                ),
              ),
            )
          else
            const SizedBox(height: 20),
        ],
      ),
    );
  }
}
