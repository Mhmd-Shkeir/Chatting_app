import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/assistant_message.dart';
import '../../data/repositories/ai_assistant_repository.dart';

final aiAssistantRepositoryProvider = Provider<AiAssistantRepository>((ref) {
  return AiAssistantRepository();
});

class AssistantState {
  const AssistantState({this.messages = const [], this.isSending = false});

  final List<AssistantMessage> messages;
  final bool isSending;

  AssistantState copyWith({List<AssistantMessage>? messages, bool? isSending}) {
    return AssistantState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
    );
  }
}

/// Not autoDispose — the conversation stays alive for the app session even
/// if the user backs out of the Assistant screen and reopens it, same
/// expectation as any other chat staying put while the app is running.
class AssistantController extends Notifier<AssistantState> {
  @override
  AssistantState build() => const AssistantState();

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;

    final userMessage = AssistantMessage(role: AssistantRole.user, text: trimmed);
    state = state.copyWith(messages: [...state.messages, userMessage], isSending: true);

    try {
      final reply = await ref.read(aiAssistantRepositoryProvider).sendMessage(state.messages);
      state = state.copyWith(
        messages: [...state.messages, AssistantMessage(role: AssistantRole.assistant, text: reply)],
        isSending: false,
      );
    } catch (_) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          const AssistantMessage(
            role: AssistantRole.assistant,
            text: "Sorry, I couldn't reach the assistant. Please check your connection and try again.",
            failed: true,
          ),
        ],
        isSending: false,
      );
    }
  }

  void clear() => state = const AssistantState();
}

final assistantControllerProvider =
    NotifierProvider<AssistantController, AssistantState>(AssistantController.new);
