import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../../core/utils/username_validator.dart';
import '../../../../core/widgets/auth_text_field_decoration.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_loading_button.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../providers/profile_providers.dart';

/// One-time onboarding step for accounts created before the username system
/// existed. The router redirects any signed-in user with no username here
/// and won't let them past it until [ProfileController.claimUsername]
/// succeeds.
class ChooseUsernameScreen extends ConsumerStatefulWidget {
  const ChooseUsernameScreen({super.key});

  @override
  ConsumerState<ChooseUsernameScreen> createState() => _ChooseUsernameScreenState();
}

class _ChooseUsernameScreenState extends ConsumerState<ChooseUsernameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  bool _autovalidate = false;
  Timer? _debounce;
  String _debouncedUsername = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _debouncedUsername = value.trim());
    });
  }

  Future<void> _submit() async {
    setState(() => _autovalidate = true);
    if (!_formKey.currentState!.validate()) return;

    await ref.read(profileControllerProvider.notifier).claimUsername(_usernameController.text);
  }

  Widget _availability(ColorScheme colorScheme) {
    final username = _debouncedUsername;
    if (username.isEmpty || !usernamePattern.hasMatch(username)) {
      return const SizedBox.shrink();
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
    final profileState = ref.watch(profileControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    ref.listen(profileControllerProvider, (previous, next) {
      if (next.hasError) {
        showErrorSnackBar(context, mapAuthError(next.error!));
      }
    });

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colorScheme.surface, colorScheme.surfaceContainerHigh],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.alternate_email,
                          size: 34,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Choose a username',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "It's how people find and mention you — you'll keep it going forward",
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 32),
                    Card(
                      elevation: 1,
                      color: colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          autovalidateMode: _autovalidate
                              ? AutovalidateMode.onUserInteraction
                              : AutovalidateMode.disabled,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _usernameController,
                                enabled: !profileState.isLoading,
                                onChanged: _onChanged,
                                decoration: authFieldDecoration(
                                  context,
                                  label: 'Username',
                                  icon: Icons.alternate_email,
                                ),
                                validator: validateUsername,
                              ),
                              _availability(colorScheme),
                              const SizedBox(height: 24),
                              PrimaryLoadingButton(
                                label: 'Continue',
                                isLoading: profileState.isLoading,
                                onPressed: _submit,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
