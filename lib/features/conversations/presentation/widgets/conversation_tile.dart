import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/presence_providers.dart';
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
    final name = conversation.otherParticipantName(myUid);
    final unread = conversation.unreadCountFor(myUid);
    final otherUid = conversation.otherParticipantId(myUid);
    final isOnline = ref.watch(presenceStatusProvider(otherUid)).value?.isOnline ?? false;

    return ListTile(
      onTap: onTap,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
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
                  border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(name),
      subtitle: Text(
        conversation.lastMessage ?? 'Say hello',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: unread > 0
          ? CircleAvatar(
              radius: 11,
              child: Text('$unread', style: const TextStyle(fontSize: 11)),
            )
          : null,
    );
  }
}
