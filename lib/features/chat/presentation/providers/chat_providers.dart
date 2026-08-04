import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/message.dart';
import '../../data/repositories/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final messagesStreamProvider = StreamProvider.family<List<Message>, String>((ref, conversationId) {
  return ref.watch(chatRepositoryProvider).streamMessages(conversationId);
});

class SendMessageController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> send({
    required String conversationId,
    required String recipientId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(chatRepositoryProvider).sendMessage(
            conversationId: conversationId,
            recipientId: recipientId,
            text: trimmed,
          );
    });
  }
}

final sendMessageControllerProvider = AsyncNotifierProvider<SendMessageController, void>(
  SendMessageController.new,
);
