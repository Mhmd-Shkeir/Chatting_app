import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_loading_button.dart';
import '../providers/auth_providers.dart';

class VerifyEmailScreen extends ConsumerWidget {
  const VerifyEmailScreen({super.key});

  Future<void> _checkVerified(BuildContext context, WidgetRef ref) async {
    final verified = await ref.read(authControllerProvider.notifier).checkEmailVerified();
    if (!context.mounted) return;

    if (verified) {
      context.go('/home');
      return;
    }

    // reload() / userChanges() don't reliably refresh emailVerified within
    // a live process on some Android SDK versions — confirmed by testing,
    // only a fresh sign-in ever picks it up correctly (same as a cold app
    // restart). Sign out and route through login again rather than leaving
    // the user stuck on this screen with no way forward — if they haven't
    // actually verified yet, login will just send them right back here.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
          content: Text(
            "If you've already verified, please log in again to continue.",
          ),
        ),
      );
    await ref.read(authControllerProvider.notifier).logout();
  }

  Future<void> _logout(WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).logout();
  }

  Future<void> _resend(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).resendVerificationEmail();
    if (!context.mounted) return;

    final error = ref.read(authControllerProvider).error;
    if (error != null) {
      showErrorSnackBar(context, mapAuthError(error));
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Verification email sent'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final email = ref.watch(authStateChangesProvider).value?.email;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
                          Icons.mark_email_unread_outlined,
                          size: 34,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Verify your email',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email != null
                          ? "We sent a verification link to $email. Open it, then come back and tap \"I've verified\"."
                          : "We sent you a verification link. Open it, then come back and tap \"I've verified\".",
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PrimaryLoadingButton(
                              label: "I've verified",
                              isLoading: authState.isLoading,
                              onPressed: () => _checkVerified(context, ref),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: colorScheme.onSurfaceVariant,
                              ),
                              onPressed:
                                  authState.isLoading ? null : () => _resend(context, ref),
                              child: const Text('Resend verification email'),
                            ),
                            const SizedBox(height: 4),
                            TextButton(
                              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                              onPressed: authState.isLoading ? null : () => _logout(ref),
                              child: const Text('Log out'),
                            ),
                          ],
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
