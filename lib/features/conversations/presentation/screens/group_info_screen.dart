import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/user_avatar.dart';
import '../../../authentication/data/models/app_user.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../authentication/presentation/providers/presence_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/models/conversation.dart';
import '../providers/conversation_providers.dart';
import '../widgets/user_multi_select_list.dart';

class GroupInfoScreen extends ConsumerWidget {
  const GroupInfoScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversation = ref.watch(conversationDetailProvider(conversationId)).value;
    final myUid = ref.watch(authStateChangesProvider).value?.uid;

    if (conversation == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isAdmin = myUid != null && conversation.admins.contains(myUid);

    return Scaffold(
      appBar: AppBar(title: const Text('Group info')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                UserAvatar(
                  photoUrl: conversation.groupAvatarUrl,
                  displayName: conversation.groupName ?? 'Group',
                  radius: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  conversation.groupName ?? 'Group',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${conversation.participants.length} members',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.person_add_alt_outlined),
            title: const Text('Add members'),
            onTap: () => _showAddMembers(context, conversation),
          ),
          ListTile(
            leading: Icon(Icons.logout, color: colorScheme.error),
            title: Text('Leave group', style: TextStyle(color: colorScheme.error)),
            onTap: () => _confirmLeaveGroup(context, ref),
          ),
          const Divider(height: 1),
          for (final uid in conversation.participants)
            _MemberTile(
              uid: uid,
              fallbackName: conversation.participantNames[uid] ?? 'Unknown',
              isCreator: uid == conversation.createdBy,
              canRemove: isAdmin && uid != myUid,
              onRemove: () => _confirmRemoveMember(
                context,
                ref,
                uid: uid,
                name: conversation.participantNames[uid] ?? 'this member',
              ),
            ),
        ],
      ),
    );
  }

  void _showAddMembers(BuildContext context, Conversation conversation) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _AddMembersSheet(
        conversationId: conversationId,
        existingParticipants: conversation.participants.toSet(),
      ),
    );
  }

  Future<void> _confirmRemoveMember(
    BuildContext context,
    WidgetRef ref, {
    required String uid,
    required String name,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text('$name will be removed from this group.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(conversationRepositoryProvider)
          .removeMember(conversationId: conversationId, uid: uid);
    }
  }

  Future<void> _confirmLeaveGroup(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave group?'),
        content: const Text(
          'You will no longer receive messages from this group. Other '
          'members keep the group as normal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(conversationRepositoryProvider).leaveGroup(conversationId);
      // Once we're no longer a participant, this doc (and the chat screen
      // still on the stack beneath this one) is no longer readable under
      // the security rules — go(), not pop(), so neither is left behind on
      // the nav stack to be revisited.
      if (context.mounted) context.go('/home');
    }
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.uid,
    required this.fallbackName,
    required this.isCreator,
    required this.canRemove,
    required this.onRemove,
  });

  final String uid;
  final String fallbackName;
  final bool isCreator;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(uid)).value;
    final isOnline = ref.watch(presenceStatusProvider(uid)).value?.isOnline ?? false;
    final isDeleted = profile?.deleted ?? false;
    final name = isDeleted ? 'Deleted Account' : (profile?.displayName ?? fallbackName);

    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          UserAvatar(photoUrl: profile?.photoUrl, displayName: name),
          if (isOnline && !isDeleted)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(name),
      subtitle: (!isDeleted && profile?.hasUsername == true)
          ? Text('@${profile!.username}')
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCreator)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Chip(
                label: Text('Creator'),
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (canRemove)
            IconButton(
              icon: Icon(Icons.person_remove_outlined, color: Theme.of(context).colorScheme.error),
              tooltip: 'Remove from group',
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

class _AddMembersSheet extends ConsumerStatefulWidget {
  const _AddMembersSheet({
    required this.conversationId,
    required this.existingParticipants,
  });

  final String conversationId;
  final Set<String> existingParticipants;

  @override
  ConsumerState<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends ConsumerState<_AddMembersSheet> {
  final Map<String, AppUser> _selected = {};
  bool _adding = false;

  void _toggle(AppUser user) {
    setState(() {
      if (_selected.containsKey(user.uid)) {
        _selected.remove(user.uid);
      } else {
        _selected[user.uid] = user;
      }
    });
  }

  Future<void> _add() async {
    if (_selected.isEmpty) return;
    setState(() => _adding = true);
    try {
      await ref.read(conversationRepositoryProvider).addMembers(
            conversationId: widget.conversationId,
            memberNames: {
              for (final user in _selected.values) user.uid: user.displayName,
            },
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add members: $error')),
        );
        setState(() => _adding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add members',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: _selected.isEmpty || _adding ? null : _add,
                    child: _adding
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: UserMultiSelectList(
                selected: _selected,
                onToggle: _toggle,
                excludeUids: widget.existingParticipants,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
