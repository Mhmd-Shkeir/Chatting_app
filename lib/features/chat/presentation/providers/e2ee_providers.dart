import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/repositories/e2ee_repository.dart';

final e2eeRepositoryProvider = Provider<E2eeRepository>((ref) {
  return E2eeRepository();
});

/// Watched once at the app root (see app.dart, alongside
/// presenceTrackerProvider) — generates/publishes this device's E2EE
/// keypair as soon as someone is signed in, so it's ready before any chat
/// might need to encrypt or decrypt. Has no value of its own; activated by
/// being watched.
final e2eeKeyTrackerProvider = Provider<void>((ref) {
  final isLoggedIn = ref.watch(authStateChangesProvider).value != null;
  if (isLoggedIn) {
    ref.read(e2eeRepositoryProvider).ensureReady();
  }
});
