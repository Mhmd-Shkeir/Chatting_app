import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/presence_status.dart';
import '../../data/repositories/presence_repository.dart';
import 'auth_providers.dart';

final presenceRepositoryProvider = Provider<PresenceRepository>((ref) {
  return PresenceRepository();
});

/// Watched once at the app root to start/stop presence tracking as the
/// auth state changes. Has no value of its own — it's activated by being
/// watched, not by being read.
final presenceTrackerProvider = Provider<void>((ref) {
  final repository = ref.watch(presenceRepositoryProvider);
  final isLoggedIn = ref.watch(authStateChangesProvider).value != null;

  if (isLoggedIn) {
    repository.startTracking();
  } else {
    repository.stopTracking();
  }
});

final presenceStatusProvider = StreamProvider.family<PresenceStatus, String>((ref, uid) {
  return ref.watch(presenceRepositoryProvider).watchPresence(uid);
});
