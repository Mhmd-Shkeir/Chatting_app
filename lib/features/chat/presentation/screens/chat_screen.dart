import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/presence_formatter.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../authentication/presentation/providers/presence_providers.dart';
import '../../../conversations/data/models/conversation.dart';
import '../../../conversations/presentation/providers/conversation_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/chat_providers.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(chatRepositoryProvider).markConversationRead(widget.conversationId),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Conversation? _findConversation(List<Conversation>? conversations) {
    if (conversations == null) return null;
    for (final conversation in conversations) {
      if (conversation.id == widget.conversationId) return conversation;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(authStateChangesProvider).value?.uid;
    final conversations = ref.watch(conversationsStreamProvider).value;
    final conversation = _findConversation(conversations);
    final otherUid =
        (myUid != null && conversation != null) ? conversation.otherParticipantId(myUid) : null;
    final otherProfile = otherUid != null ? ref.watch(userProfileProvider(otherUid)).value : null;
    // Same reasoning as ConversationTile: participantNames is a frozen
    // snapshot that never learns about account deletion, so that has to
    // come from the live per-uid lookup instead.
    final isDeleted = otherProfile?.deleted ?? false;
    final otherName = isDeleted
        ? 'Deleted Account'
        : (myUid != null && conversation != null)
            ? conversation.otherParticipantName(myUid)
            : 'Chat';

    final messagesAsync = ref.watch(messagesStreamProvider(widget.conversationId));
    final sendState = ref.watch(sendMessageControllerProvider);
    // A deleted account must never be presence-listened-to at all, let
    // alone shown as online or with a last-seen time.
    final presence = (otherUid != null && !isDeleted)
        ? ref.watch(presenceStatusProvider(otherUid)).value
        : null;
    final otherUsername = otherProfile?.username;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(otherName, overflow: TextOverflow.ellipsis)),
                if (otherUsername != null && otherUsername.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '@$otherUsername',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ],
            ),
            if (presence != null)
              Text(
                presence.isOnline ? 'Online' : formatLastSeen(presence.lastSeen),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Something went wrong: $error')),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet. Say hello.'));
                }
                if (otherUid != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(chatRepositoryProvider).markMessagesRead(
                          conversationId: widget.conversationId,
                          otherUid: otherUid,
                        );
                  });
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return MessageBubble(message: message, isMine: message.senderId == myUid);
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _textController,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Message',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(otherUid),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: sendState.isLoading
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.send),
                    onPressed: sendState.isLoading ? null : () => _send(otherUid),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send(String? recipientId) async {
    if (recipientId == null) return;
    final text = _textController.text;
    _textController.clear();
    await ref.read(sendMessageControllerProvider.notifier).send(
          conversationId: widget.conversationId,
          recipientId: recipientId,
          text: text,
        );
  }
}
