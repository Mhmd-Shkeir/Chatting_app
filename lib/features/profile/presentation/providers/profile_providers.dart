import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/data/models/app_user.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../authentication/presentation/providers/presence_providers.dart';
import '../../data/repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final currentUserProfileProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(profileRepositoryProvider).watchUser(uid);
});

/// Live per-uid profile lookup, independent of the frozen `participantNames`
/// snapshot stored on conversation docs — used only to render `@username`
/// until conversation metadata is refactored to resolve fully live.
final userProfileProvider = StreamProvider.family<AppUser?, String>((ref, uid) {
  return ref.watch(profileRepositoryProvider).watchUser(uid);
});

/// Presence cleanup (best-effort) + Auth-account deletion (retried). Split
/// out of [ProfileController.deleteAccount] so router.dart can call the
/// exact same tail when it detects a deletion that got interrupted after
/// the Firestore tombstone landed but before the Auth account itself was
/// actually removed — see the comment on router.dart's currentUserProfileProvider
/// listener for why that recovery path exists and why it must reuse this,
/// not a copy of it.
///
/// Deliberately a top-level function, not a method on [ProfileController]:
/// the tombstone write's local-cache echo reaches currentUserProfileProvider
/// (and therefore router.dart) well before tombstoneUserDoc()'s own await on
/// waitForPendingWrites() resolves, so router.dart can observe "deleted:
/// true" and be tempted to finish the job while THIS SAME call is still
/// running from ProfileController.deleteAccount() on the very same
/// instance. Callers are responsible for not invoking this twice
/// concurrently for the same uid (see both call sites' guards).
Future<void> finishAccountDeletion(Ref ref, String uid) async {
  final authRepository = ref.read(authRepositoryProvider);

  // [uid] can be stale by the time this actually runs. Concretely:
  // router.dart's self-heal reads it off a currentUserProfileProvider
  // snapshot, and Riverpod's own "isReloading" behavior means a provider
  // that rebuilds because a watched dependency changed (here,
  // authStateChangesProvider flipping to a different uid, or to null)
  // still exposes the *previous* emission via `.value` until the new
  // stream produces something — which, for the empty stream used when
  // nobody's signed in, never happens. So the self-heal can still see this
  // account's tombstoned doc for a brief window after its own deletion has
  // already fully finished and a completely different account has since
  // signed in on this device. Refusing to proceed unless [uid] still
  // matches whoever is actually signed in right now is what stops that
  // stale read from tearing down (via the presence cleanup below, which
  // acts on this device's single shared PresenceRepository and whatever
  // uid it's currently tracking, not specifically on [uid]) or deleting
  // (via authRepository.deleteAccount's own matching check, kept as a
  // second layer in case the signed-in user changes again during the
  // awaits below) that unrelated, live session instead.
  if (authRepository.currentUser?.uid != uid) return;

  // Best-effort, deliberately: the account and its data are already
  // committed to being deleted at this point, so a leftover presence node
  // (a cosmetic online/offline dot) must never be able to block the Auth
  // deletion below.
  try {
    final presenceRepository = ref.read(presenceRepositoryProvider);
    // stopTracking() cancels the live onDisconnect/reconnect listener
    // first — without this, that listener can rewrite isOnline: true right
    // after deletePresence() removes the node, the moment the RTDB socket
    // so much as blips, since nothing told it to stop.
    await presenceRepository.stopTracking();
    await presenceRepository.deletePresence(uid);
  } catch (_) {
    // Swallowed deliberately — see comment above.
  }

  // There's no cross-system transaction between Firestore and Firebase
  // Auth, so this final step can't be made atomic with the tombstone write
  // that already happened — if every attempt below fails, the account is
  // left signed-in with an already-wiped profile, which is exactly the
  // state router.dart's self-heal watches for and retries. Every step here
  // is idempotent (re-removing presence and retrying delete are both safe
  // to repeat), so retrying narrows — without eliminating — the window
  // where a transient failure could strand it mid-deletion. Each attempt
  // gets its own timeout so a hung network call can't wedge this forever —
  // that matters most to router.dart's caller, which relies on this
  // eventually resolving to reset its own re-entrancy guard.
  Object? lastError;
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      await authRepository.deleteAccount(uid).timeout(const Duration(seconds: 10));
      return;
    } catch (error) {
      lastError = error;
      if (attempt < 2) await Future.delayed(const Duration(milliseconds: 500));
    }
  }
  throw lastError!;
}

class ProfileController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateDisplayName(String displayName) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(profileRepositoryProvider).updateDisplayName(displayName);
    });
  }

  Future<void> claimUsername(String username) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(profileRepositoryProvider).claimUsername(username);
    });
  }

  Future<void> deleteAccount(String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authRepositoryProvider).currentUser?.uid;
      // Every step below silently no-ops on a null currentUser (see
      // ProfileRepository.reauthenticate/tombstoneUserDoc and
      // AuthRepository.deleteAccount's null-safe navigation) — without
      // this guard, calling this with nobody signed in would sail through
      // doing nothing and still report success.
      if (uid == null) throw StateError('No signed-in user to delete.');

      final profileRepository = ref.read(profileRepositoryProvider);

      // Order matters: every write here needs request.auth to still be
      // this account, so all Firestore/RTDB cleanup must happen before
      // the Auth account itself is deleted.
      await profileRepository.reauthenticate(password);
      await profileRepository.tombstoneUserDoc();

      // From here, router.dart's currentUserProfileProvider listener may
      // already be racing this exact call the instant the tombstone's
      // local-cache echo lands (see finishAccountDeletion's doc comment) —
      // it recognizes that via profileControllerProvider.isLoading (true
      // for this call's entire duration, set above) and defers to us.
      await finishAccountDeletion(ref, uid);
    });
  }
}

final profileControllerProvider = AsyncNotifierProvider<ProfileController, void>(
  ProfileController.new,
);
