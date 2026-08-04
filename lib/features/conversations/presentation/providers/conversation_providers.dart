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
