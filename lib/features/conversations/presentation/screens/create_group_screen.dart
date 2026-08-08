import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/widgets/photo_source_sheet.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../authentication/data/models/app_user.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/conversation_providers.dart';
import '../widgets/user_multi_select_list.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final Map<String, AppUser> _selected = {};
  XFile? _pickedAvatar;
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _toggle(AppUser user) {
    setState(() {
      if (_selected.containsKey(user.uid)) {
        _selected.remove(user.uid);
      } else {
        _selected[user.uid] = user;
      }
    });
  }

  Future<void> _pickAvatar() async {
    final action = await showModalBottomSheet<PhotoSourceAction>(
      context: context,
      builder: (context) => PhotoSourceSheet(showRemove: _pickedAvatar != null),
    );
    if (action == null || !mounted) return;
    if (action == PhotoSourceAction.remove) {
      setState(() => _pickedAvatar = null);
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: action == PhotoSourceAction.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _pickedAvatar = picked);
  }

  bool get _canCreate =>
      _nameController.text.trim().isNotEmpty && _selected.isNotEmpty && !_creating;

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selected.isEmpty) return;

    setState(() => _creating = true);
    try {
      String? avatarUrl;
      final avatar = _pickedAvatar;
      if (avatar != null) {
        avatarUrl = await ref
            .read(imageKitRepositoryProvider)
            .uploadImage(
              File(avatar.path),
              fileName: 'group_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
      }
      final conversationId = await ref
          .read(conversationRepositoryProvider)
          .createGroup(
            name: name,
            avatarUrl: avatarUrl,
            memberNames: {
              for (final user in _selected.values) user.uid: user.displayName,
            },
          );
      if (mounted) context.pushReplacement('/chat/$conversationId');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create group: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New group'),
        actions: [
          TextButton(
            onPressed: _canCreate ? _create : null,
            child: _creating
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      _pickedAvatar != null
                          ? CircleAvatar(
                              radius: 28,
                              backgroundImage: FileImage(File(_pickedAvatar!.path)),
                            )
                          : UserAvatar(
                              photoUrl: null,
                              displayName: _nameController.text,
                              radius: 28,
                            ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: CircleAvatar(
                          radius: 11,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: Icon(
                            Icons.camera_alt,
                            size: 13,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Group name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final user in _selected.values)
                    Chip(
                      avatar: UserAvatar(
                        photoUrl: user.photoUrl,
                        displayName: user.displayName,
                        radius: 12,
                      ),
                      label: Text(user.displayName),
                      onDeleted: () => _toggle(user),
                    ),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: UserMultiSelectList(selected: _selected, onToggle: _toggle),
          ),
        ],
      ),
    );
  }
}
