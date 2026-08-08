import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/user_avatar.dart';
import '../../../authentication/data/models/app_user.dart';
import '../../../search/presentation/providers/user_search_providers.dart';

/// Search + checkbox-select list of users, shared between the create-group
/// flow and "Add members" on an existing group. [selected] is uid -> AppUser
/// (not just a set of uids) so callers that render the selection as chips
/// keep the display info without a second lookup. [excludeUids] hides users
/// who can't be selected here — e.g. already in the group being edited.
class UserMultiSelectList extends ConsumerStatefulWidget {
  const UserMultiSelectList({
    required this.selected,
    required this.onToggle,
    this.excludeUids = const {},
    super.key,
  });

  final Map<String, AppUser> selected;
  final ValueChanged<AppUser> onToggle;
  final Set<String> excludeUids;

  @override
  ConsumerState<UserMultiSelectList> createState() => _UserMultiSelectListState();
}

class _UserMultiSelectListState extends ConsumerState<UserMultiSelectList> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _query = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(userSearchResultsProvider(_query));
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(22),
            ),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Search by name or @username',
                prefixIcon: Icon(Icons.search, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: _onChanged,
            ),
          ),
        ),
        Expanded(
          child: resultsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Something went wrong: $error')),
            data: (users) {
              final visible =
                  users.where((u) => !widget.excludeUids.contains(u.uid)).toList();
              if (_query.trim().isEmpty) {
                return Center(
                  child: Text(
                    'Start typing to find people',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                );
              }
              if (visible.isEmpty) {
                return Center(
                  child: Text(
                    'No users found',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                );
              }
              return ListView.builder(
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final user = visible[index];
                  final isSelected = widget.selected.containsKey(user.uid);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (_) => widget.onToggle(user),
                    controlAffinity: ListTileControlAffinity.trailing,
                    secondary: UserAvatar(
                      photoUrl: user.photoUrl,
                      displayName: user.displayName,
                    ),
                    title: Text(user.displayName),
                    subtitle: user.hasUsername ? Text('@${user.username}') : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
