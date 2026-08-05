import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../providers/conversation_providers.dart';
import '../widgets/conversation_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(authStateChangesProvider).value?.uid;
    final conversationsAsync = ref.watch(conversationsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lumina Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: myUid == null
          ? const SizedBox.shrink()
          : conversationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Something went wrong: $error')),
              data: (conversations) {
                if (conversations.isEmpty) {
                  return const Center(
                    child: Text('No conversations yet. Search for someone to start chatting.'),
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
                      ref.read(chatRepositoryProvider).markMessagesDelivered(
                            conversationId: conversation.id,
                            otherUid: senderId,
                          );
                    }
                  }
                });

                return ListView.separated(
                  itemCount: conversations.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    return ConversationTile(
                      conversation: conversation,
                      myUid: myUid,
                      onTap: () => context.push('/chat/${conversation.id}'),
                    );
                  },
                );
              },
            ),
    );
  }
}
