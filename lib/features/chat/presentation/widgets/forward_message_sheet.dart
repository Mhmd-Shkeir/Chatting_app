import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/root_scaffold_messenger_key.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../conversations/data/models/conversation.dart';
import '../../../conversations/presentation/providers/conversation_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/models/message.dart';
import '../providers/chat_providers.dart';

/// Picks a target conversation to forward [message] into — a flat list of
/// the sender's existing conversations (direct or group), reusing
/// conversationsStreamProvider rather than a new query.
Future<void> showForwardMessageSheet(
  BuildContext context, {
  required WidgetRef ref,
  required Message message,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _ForwardSheet(message: message),
  );
}

class _ForwardSheet extends ConsumerWidget {
  const _ForwardSheet({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(authStateChangesProvider).value?.uid;
    final conversationsAsync = ref.watch(conversationsStreamProvider);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Forward to',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: conversationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Center(child: Text('Something went wrong: $error')),
                data: (conversations) {
                  if (conversations.isEmpty || myUid == null) {
                    return const Center(child: Text('No conversations yet.'));
                  }
                  return ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      return _ForwardTargetTile(
                        conversation: conversations[index],
                        myUid: myUid,
                        message: message,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One forward target row — resolves a direct conversation's display name
/// live (see conversation_tile.dart's same fix) instead of the frozen
/// participantNames snapshot, so a recent display-name edit shows up here
/// immediately. Groups use their own groupName, which isn't per-user and
/// so has no staleness problem.
class _ForwardTargetTile extends ConsumerWidget {
  const _ForwardTargetTile({
    required this.conversation,
    required this.myUid,
    required this.message,
  });

  final Conversation conversation;
  final String myUid;
  final Message message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGroup = conversation.isGroup;
    final otherUid = isGroup ? null : conversation.otherParticipantId(myUid);
    final otherProfile = otherUid != null
        ? ref.watch(userProfileProvider(otherUid)).value
        : null;
    final displayName = isGroup
        ? conversation.displayNameFor(myUid)
        : (otherProfile?.displayName ?? conversation.displayNameFor(myUid));
    final targetRecipientIds = conversation.otherParticipantIds(myUid);

    return ListTile(
      leading: UserAvatar(
        photoUrl: isGroup ? conversation.groupAvatarUrl : otherProfile?.photoUrl,
        displayName: displayName,
        radius: 20,
      ),
      title: Text(displayName),
      onTap: () async {
        Navigator.of(context).pop();
        try {
          await ref.read(chatRepositoryProvider).forwardMessage(
                targetConversationId: conversation.id,
                targetRecipientIds: targetRecipientIds,
                message: message,
              );
          rootScaffoldMessengerKey.currentState
            ?..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text('Forwarded to $displayName')));
        } catch (_) {
          rootScaffoldMessengerKey.currentState
            ?..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Forward failed')));
        }
      },
    );
  }
}
