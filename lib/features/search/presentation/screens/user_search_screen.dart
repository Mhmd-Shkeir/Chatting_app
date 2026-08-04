import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../conversations/presentation/providers/conversation_providers.dart';
import '../providers/user_search_providers.dart';

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
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

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by name',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
      ),
      body: resultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Something went wrong: $error')),
        data: (users) {
          if (_query.trim().isEmpty) {
            return const Center(child: Text('Start typing to find people'));
          }
          if (users.isEmpty) {
            return const Center(child: Text('No users found'));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                  ),
                ),
                title: Text(user.displayName),
                subtitle: Text(user.email),
                onTap: () async {
                  final conversationId = await ref
                      .read(conversationRepositoryProvider)
                      .getOrCreateConversation(
                        otherUserId: user.uid,
                        otherUserDisplayName: user.displayName,
                      );
                  if (context.mounted) {
                    context.push('/chat/$conversationId');
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
