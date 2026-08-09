import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../../core/utils/username_validator.dart';
import '../../../../core/widgets/auth_text_field_decoration.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/google_sign_in_button.dart';
import '../../../../core/widgets/primary_loading_button.dart';
import '../providers/auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _autovalidate = false;
  Timer? _usernameDebounce;
  String _debouncedUsername = '';

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    _usernameDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _debouncedUsername = value.trim());
    });
  }

  Future<void> _submit() async {
    setState(() => _autovalidate = true);
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authControllerProvider.notifier).register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
          username: _usernameController.text.trim(),
        );
  }

  Widget _usernameAvailability(ColorScheme colorScheme) {
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
    final authState = ref.watch(authControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    ref.listen(authControllerProvider, (previous, next) {
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
                          Icons.person_add_alt_1_rounded,
                          size: 34,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Create account',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join Lumina Chat to start messaging',
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
                                controller: _nameController,
                                enabled: !authState.isLoading,
                                decoration: authFieldDecoration(
                                  context,
                                  label: 'Display name',
                                  icon: Icons.person_outline,
                                ),
                                validator: (value) => (value == null || value.trim().isEmpty)
                                    ? 'Enter a display name'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _usernameController,
                                enabled: !authState.isLoading,
                                onChanged: _onUsernameChanged,
                                decoration: authFieldDecoration(
                                  context,
                                  label: 'Username',
                                  icon: Icons.alternate_email,
                                ),
                                validator: validateUsername,
                              ),
                              _usernameAvailability(colorScheme),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                enabled: !authState.isLoading,
                                keyboardType: TextInputType.emailAddress,
                                decoration: authFieldDecoration(
                                  context,
                                  label: 'Email',
                                  icon: Icons.mail_outline,
                                ),
                                validator: (value) => (value == null || !value.contains('@'))
                                    ? 'Enter a valid email'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                enabled: !authState.isLoading,
                                obscureText: _obscurePassword,
                                decoration: authFieldDecoration(
                                  context,
                                  label: 'Password',
                                  icon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: (value) => (value == null || value.length < 6)
                                    ? 'Minimum 6 characters'
                                    : null,
                              ),
                              const SizedBox(height: 24),
                              PrimaryLoadingButton(
                                label: 'Create account',
                                isLoading: authState.isLoading,
                                onPressed: _submit,
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(child: Divider(color: colorScheme.outlineVariant)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      'or',
                                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: colorScheme.outlineVariant)),
                                ],
                              ),
                              const SizedBox(height: 20),
                              GoogleSignInButton(
                                isLoading: authState.isLoading,
                                onPressed: () => ref
                                    .read(authControllerProvider.notifier)
                                    .signInWithGoogle(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () => context.go('/login'),
                        child: const Text('Already have an account? Log in'),
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
