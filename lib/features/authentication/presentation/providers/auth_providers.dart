import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';
import 'presence_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// For anything that needs to react to emailVerified specifically —
/// unlike authStateChangesProvider, this also emits after reload().
final userChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).userChanges();
});

final usernameAvailabilityProvider = FutureProvider.family<bool, String>((ref, username) {
  if (username.trim().isEmpty) return Future.value(false);
  return ref.read(authRepositoryProvider).isUsernameAvailable(username);
});

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String username,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(authRepositoryProvider).register(
            email: email,
            password: password,
            displayName: displayName,
            username: username,
          );
    });
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(authRepositoryProvider).login(email: email, password: password);
    });
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // Presence must go offline while the user is still authenticated —
      // the Realtime Database rule requires auth.uid == the presence node's
      // uid, and that check fails once signOut() has already invalidated
      // the session. Reversing this order caused writes to be silently
      // rejected with permission-denied.
      await ref.read(presenceRepositoryProvider).stopTracking();
      await ref.read(authRepositoryProvider).logout();
    });
  }

  Future<void> resendVerificationEmail() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(authRepositoryProvider).sendEmailVerification();
    });
  }

  /// Returns the up-to-date verified status so the Verify Email screen can
  /// branch on it directly, while [state] still carries loading/error for
  /// the rest of the UI.
  Future<bool> checkEmailVerified() async {
    state = const AsyncLoading();
    var verified = false;
    state = await AsyncValue.guard(() async {
      verified = await ref.read(authRepositoryProvider).checkEmailVerified();
    });
    return verified;
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
