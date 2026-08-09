import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/models/conversation.dart';
import '../../data/repositories/conversation_repository.dart';

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository();
});

final conversationsStreamProvider = StreamProvider<List<Conversation>>((ref) {
  final myUid = ref.watch(authStateChangesProvider).value?.uid;
  if (myUid == null) return const Stream.empty();
  return ref.watch(conversationRepositoryProvider).streamConversations(myUid);
});

/// Every group the current user belongs to, ignoring "cleared" state —
/// backs the Groups filter chip on the home screen so a cleared/"deleted"
/// group is always still reachable there. See
/// ConversationRepository.streamAllGroups.
final groupConversationsStreamProvider = StreamProvider<List<Conversation>>((
  ref,
) {
  final myUid = ref.watch(authStateChangesProvider).value?.uid;
  if (myUid == null) return const Stream.empty();
  return ref.watch(conversationRepositoryProvider).streamAllGroups(myUid);
});

/// Direct-by-ID, never filtered by "cleared" state — see
/// ConversationRepository.streamConversation for why this has to be a
/// separate provider from [conversationsStreamProvider] rather than a
/// lookup into its (list-visibility-filtered) results.
final conversationDetailProvider =
    StreamProvider.family<Conversation?, String>((ref, conversationId) {
  return ref
      .watch(conversationRepositoryProvider)
      .streamConversation(conversationId);
});
