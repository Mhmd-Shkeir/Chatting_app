import 'package:flutter/material.dart';

/// Shared between the Login and Register screens — Google Sign-In serves
/// both at once (a new Google account creates a profile on first use, see
/// AuthRepository.signInWithGoogle), so there's only one button to build.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({required this.isLoading, required this.onPressed, super.key});

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'G',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                const Text('Continue with Google'),
              ],
            ),
    );
  }
}
