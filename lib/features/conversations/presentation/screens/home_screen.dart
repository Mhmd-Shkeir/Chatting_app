import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/lumina_mark.dart';
import '../../../../core/widgets/offline_banner.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/conversation_providers.dart';
import '../widgets/conversation_tile.dart';

enum _HomeFilter { all, groups }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _HomeFilter _filter = _HomeFilter.all;

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(authStateChangesProvider).value?.uid;
    // Always watched (regardless of which filter is displayed) so the
    // delivered-receipt side effect below keeps running for the whole
    // session, same as before this filter existed — see its comment.
    final allConversationsAsync = ref.watch(conversationsStreamProvider);
    final groupsAsync = ref.watch(groupConversationsStreamProvider);
    final conversationsAsync =
        _filter == _HomeFilter.groups ? groupsAsync : allConversationsAsync;
    final myProfile = ref.watch(currentUserProfileProvider).value;

    // "Delivered" means this device has received the message — detected
    // here, off the unfiltered list, because the conversations stream is
    // already active for the whole session, not just while a specific
    // chat is open. Deliberately independent of which filter chip is
    // selected/displayed below, and of clearedFor, so delivery still
    // updates for a chat that's currently hidden from view.
    final allConversations = allConversationsAsync.value;
    if (myUid != null && allConversations != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final conversation in allConversations) {
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
    }

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
          : Column(
              children: [
                const OfflineBanner(),
                _HomeFilterChips(
                  selected: _filter,
                  onSelect: (filter) => setState(() => _filter = filter),
                ),
                Expanded(
                  child: conversationsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) =>
                        Center(child: Text('Something went wrong: $error')),
                    data: (conversations) {
                      if (conversations.isEmpty) {
                        final isGroupsFilter = _filter == _HomeFilter.groups;
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isGroupsFilter
                                      ? Icons.group_outlined
                                      : Icons.chat_bubble_outline,
                                  size: 48,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  isGroupsFilter
                                      ? 'No groups yet'
                                      : 'No conversations yet',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isGroupsFilter
                                      ? 'Create a group to see it here.'
                                      : 'Search for someone to start chatting.',
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

                      return ListView.separated(
                        itemCount: conversations.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (context, index) {
                          final conversation = conversations[index];
                          return ConversationTile(
                            conversation: conversation,
                            myUid: myUid,
                            onTap: () =>
                                context.push('/chat/${conversation.id}'),
                            onLongPress: () => _confirmDeleteChat(
                              context,
                              ref,
                              conversation.id,
                              isGroup: conversation.isGroup,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Lumina Assistant',
        onPressed: () => context.push('/assistant'),
        child: LuminaMark(size: 26, markColor: Theme.of(context).colorScheme.onPrimaryContainer),
      ),
    );
  }
}

/// WhatsApp-style filter row under the app bar: "All" (default) and
/// "Groups" — selecting "Groups" switches the list to
/// [groupConversationsStreamProvider], which always includes every group
/// the user belongs to regardless of "cleared" state (see that provider).
class _HomeFilterChips extends StatelessWidget {
  const _HomeFilterChips({required this.selected, required this.onSelect});

  final _HomeFilter selected;
  final ValueChanged<_HomeFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            selected: selected == _HomeFilter.all,
            onTap: () => onSelect(_HomeFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Groups',
            icon: Icons.group_outlined,
            selected: selected == _HomeFilter.groups,
            onTap: () => onSelect(_HomeFilter.groups),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: selected ? colorScheme.onSecondaryContainer : null,
            ),
            const SizedBox(width: 4),
          ],
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
    );
  }
}

Future<void> _confirmDeleteChat(
  BuildContext context,
  WidgetRef ref,
  String conversationId, {
  bool isGroup = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete chat?'),
      content: Text(
        isGroup
            ? 'This removes the group from your main list only — you stay '
                  'a member, and it\'s always reachable under the Groups '
                  'filter. It reappears here in "All" if there\'s new '
                  'activity.'
            : 'This removes the conversation from your list only — the '
                  'other person keeps seeing it normally. It reappears here '
                  'if they send a new message.',
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
