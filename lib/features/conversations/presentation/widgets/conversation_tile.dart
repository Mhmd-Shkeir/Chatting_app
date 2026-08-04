import 'package:flutter/material.dart';

import '../../data/models/conversation.dart';

class ConversationTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final name = conversation.otherParticipantName(myUid);
    final unread = conversation.unreadCountFor(myUid);

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
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
