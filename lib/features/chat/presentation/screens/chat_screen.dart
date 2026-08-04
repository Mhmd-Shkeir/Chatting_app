import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../conversations/data/models/conversation.dart';
import '../../../conversations/presentation/providers/conversation_providers.dart';
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
    final otherName = (myUid != null && conversation != null)
        ? conversation.otherParticipantName(myUid)
        : 'Chat';
    final otherUid =
        (myUid != null && conversation != null) ? conversation.otherParticipantId(myUid) : null;

    final messagesAsync = ref.watch(messagesStreamProvider(widget.conversationId));
    final sendState = ref.watch(sendMessageControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(otherName)),
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
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(hintText: 'Message'),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(otherUid),
                    ),
                  ),
                  IconButton(
                    icon: sendState.isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
