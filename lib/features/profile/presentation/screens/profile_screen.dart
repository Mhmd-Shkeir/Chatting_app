import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../../core/utils/username_validator.dart';
import '../../../../core/widgets/auth_text_field_decoration.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/photo_source_sheet.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../providers/profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _editDisplayName(BuildContext context, WidgetRef ref, String currentName) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => _EditDisplayNameDialog(currentName: currentName),
    );

    if (newName != null && newName.trim().isNotEmpty && context.mounted) {
      await ref.read(profileControllerProvider.notifier).updateDisplayName(newName);
      final error = ref.read(profileControllerProvider).error;
      if (error != null && context.mounted) {
        showErrorSnackBar(context, mapAuthError(error));
      }
    }
  }

  Future<void> _editUsername(
    BuildContext context,
    WidgetRef ref,
    String currentUsername,
  ) async {
    final newUsername = await showDialog<String>(
      context: context,
      builder: (context) => _EditUsernameDialog(currentUsername: currentUsername),
    );
    // A no-op if unchanged — skip the write (and the transaction re-claiming
    // a username you already own) entirely.
    if (newUsername == null ||
        newUsername.toLowerCase() == currentUsername.toLowerCase() ||
        !context.mounted) {
      return;
    }

    await ref.read(profileControllerProvider.notifier).claimUsername(newUsername);
    final error = ref.read(profileControllerProvider).error;
    if (error != null && context.mounted) {
      showErrorSnackBar(context, mapAuthError(error));
    }
  }

  void _deleteAccount(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const _DeleteAccountDialog(),
    );
  }

  Future<void> _changePhoto(BuildContext context, WidgetRef ref, {required bool hasPhoto}) async {
    final action = await showModalBottomSheet<PhotoSourceAction>(
      context: context,
      builder: (context) => PhotoSourceSheet(showRemove: hasPhoto),
    );
    if (action == null || !context.mounted) return;

    final controller = ref.read(profileControllerProvider.notifier);
    if (action == PhotoSourceAction.remove) {
      await controller.removeProfilePhoto();
    } else {
      final picked = await ImagePicker().pickImage(
        source: action == PhotoSourceAction.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked == null || !context.mounted) return;
      await controller.updateProfilePhoto(picked);
    }

    if (!context.mounted) return;
    final error = ref.read(profileControllerProvider).error;
    if (error != null) {
      showErrorSnackBar(context, mapAuthError(error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final profileAsync = ref.watch(currentUserProfileProvider);
    final authState = ref.watch(authControllerProvider);
    final profileState = ref.watch(profileControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Something went wrong: $error')),
        data: (user) {
          if (user == null) return const SizedBox.shrink();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Stack(
                    children: [
                      UserAvatar(photoUrl: user.photoUrl, displayName: user.displayName, radius: 48),
                      if (profileState.isLoading)
                        Positioned.fill(
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.black45,
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: profileState.isLoading
                              ? null
                              : () => _changePhoto(context, ref, hasPhoto: user.photoUrl != null),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: colorScheme.primary,
                            child: Icon(
                              Icons.camera_alt_outlined,
                              size: 16,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user.displayName,
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (user.hasUsername) ...[
                  const SizedBox(height: 2),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: profileState.isLoading
                        ? null
                        : () => _editUsername(context, ref, user.username!),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '@${user.username}',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  user.email,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Icon(Icons.edit_outlined, color: colorScheme.primary),
                    title: const Text('Edit profile'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _editDisplayName(context, ref, user.displayName),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: authState.isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.error,
                            ),
                          )
                        : Icon(Icons.logout, color: colorScheme.error),
                    title: Text('Logout', style: TextStyle(color: colorScheme.error)),
                    onTap: authState.isLoading
                        ? null
                        : () => ref.read(authControllerProvider.notifier).logout(),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Icon(Icons.delete_forever_outlined, color: colorScheme.error),
                    title: Text('Delete account', style: TextStyle(color: colorScheme.error)),
                    onTap: () => _deleteAccount(context),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EditDisplayNameDialog extends StatefulWidget {
  const _EditDisplayNameDialog({required this.currentName});

  final String currentName;

  @override
  State<_EditDisplayNameDialog> createState() => _EditDisplayNameDialogState();
}

class _EditDisplayNameDialogState extends State<_EditDisplayNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.currentName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: authFieldDecoration(
            context,
            label: 'Display name',
            icon: Icons.person_outline,
          ),
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? 'Enter a display name' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Same live-availability UX as [ChooseUsernameScreen], reused for editing
/// an existing username rather than claiming one for the first time — the
/// underlying [ProfileController.claimUsername] transaction doesn't care
/// which case it is.
class _EditUsernameDialog extends ConsumerStatefulWidget {
  const _EditUsernameDialog({required this.currentUsername});

  final String currentUsername;

  @override
  ConsumerState<_EditUsernameDialog> createState() => _EditUsernameDialogState();
}

class _EditUsernameDialogState extends ConsumerState<_EditUsernameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.currentUsername);
  Timer? _debounce;
  late String _debouncedUsername = widget.currentUsername;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _debouncedUsername = value.trim());
    });
  }

  Widget _availability(ColorScheme colorScheme) {
    final username = _debouncedUsername;
    if (username.isEmpty || !usernamePattern.hasMatch(username)) {
      return const SizedBox.shrink();
    }
    // Re-checking your own current username against the registry would
    // always come back "taken" (you're the one holding it) — that's not
    // useful feedback, so it's special-cased instead of hitting Firestore.
    if (username.toLowerCase() == widget.currentUsername.toLowerCase()) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Text(
          'This is your current username',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    final availability = ref.watch(usernameAvailabilityProvider(username.toLowerCase()));

    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: availability.when(
        loading: () => Text(
          'Checking availability…',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        error: (_, _) => const SizedBox.shrink(),
        data: (isAvailable) => Text(
          isAvailable ? '@$username is available' : '@$username is already taken',
          style: TextStyle(
            fontSize: 12,
            color: isAvailable ? Colors.lightGreen : colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Edit username'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              decoration: authFieldDecoration(
                context,
                label: 'Username',
                icon: Icons.alternate_email,
              ),
              validator: validateUsername,
            ),
            _availability(colorScheme),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    await ref
        .read(profileControllerProvider.notifier)
        .deleteAccount(_passwordController.text);

    if (!mounted) return;

    final error = ref.read(profileControllerProvider).error;
    if (error != null) {
      // Stay open and show exactly why it failed — this used to pop
      // immediately regardless of outcome, so a failed attempt (e.g. wrong
      // password) looked identical to a successful one: dialog gone, no
      // visible confirmation either way.
      setState(() {
        _isSubmitting = false;
        _errorMessage = mapAuthError(error);
      });
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Delete account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This permanently deletes your account. This cannot be undone. '
            'Your existing messages will remain visible to the people you '
            "talked to, but your profile will show as \"Deleted Account\".",
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _passwordController,
              autofocus: true,
              enabled: !_isSubmitting,
              obscureText: _obscurePassword,
              decoration: authFieldDecoration(
                context,
                label: 'Confirm your password',
                icon: Icons.lock_outline,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Enter your password' : null,
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(_errorMessage!, style: TextStyle(color: colorScheme.error, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onError,
                  ),
                )
              : const Text('Delete account'),
        ),
      ],
    );
  }
}
