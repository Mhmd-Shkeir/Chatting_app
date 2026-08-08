import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/lumina_mark.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/conversation_providers.dart';
import '../widgets/conversation_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(authStateChangesProvider).value?.uid;
    final conversationsAsync = ref.watch(conversationsStreamProvider);
    final myProfile = ref.watch(currentUserProfileProvider).value;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: UserAvatar(
            photoUrl: myProfile?.photoUrl,
            displayName: myProfile?.displayName ?? '',
            radius: 16,
          ),
          onPressed: () => context.push('/settings'),
        ),
        title: const Text('Lumina Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'New group',
            onPressed: () => context.push('/new-group'),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: myUid == null
          ? const SizedBox.shrink()
          : conversationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Something went wrong: $error')),
              data: (conversations) {
                if (conversations.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No conversations yet',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Search for someone to start chatting.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // "Delivered" means this device has received the message —
                // detected here because the conversations stream is already
                // active for the whole session, not just while a specific
                // chat is open. Reuses existing infrastructure instead of a
                // dedicated background listener.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  for (final conversation in conversations) {
                    final senderId = conversation.lastMessageSenderId;
                    if (senderId != null && senderId != myUid) {
                      ref
                          .read(chatRepositoryProvider)
                          .markMessagesDelivered(
                            conversationId: conversation.id,
                            myUid: myUid,
                          );
                    }
                  }
                });

                return ListView.separated(
                  itemCount: conversations.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    return ConversationTile(
                      conversation: conversation,
                      myUid: myUid,
                      onTap: () => context.push('/chat/${conversation.id}'),
                      onLongPress: () =>
                          _confirmDeleteChat(context, ref, conversation.id),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Lumina Assistant',
        onPressed: () => context.push('/assistant'),
        child: LuminaMark(size: 26, markColor: Theme.of(context).colorScheme.onPrimaryContainer),
      ),
    );
  }
}

Future<void> _confirmDeleteChat(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete chat?'),
      content: const Text(
        'This removes the conversation from your list only — the other '
        'person keeps seeing it normally. It reappears here if they send '
        'a new message.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(conversationRepositoryProvider).clearChatForMe(conversationId);
  }
}
