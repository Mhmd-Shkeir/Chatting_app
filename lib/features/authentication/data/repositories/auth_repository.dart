import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/username_taken_exception.dart';

class AuthRepository {
  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Unlike [authStateChanges], also emits when the signed-in user's own
  /// profile changes (reload(), updateDisplayName(), etc.) — what the
  /// router needs to reactively notice emailVerified flipping to true.
  Stream<User?> userChanges() => _auth.userChanges();

  User? get currentUser => _auth.currentUser;

  Future<bool> isUsernameAvailable(String username) async {
    final usernameLower = username.trim().toLowerCase();
    if (usernameLower.isEmpty) return false;
    final doc = await _firestore.collection('usernames').doc(usernameLower).get();
    return !doc.exists;
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String username,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user!;
    final trimmedName = displayName.trim();
    final trimmedUsername = username.trim();
    final usernameLower = trimmedUsername.toLowerCase();

    try {
      await user.updateDisplayName(trimmedName);

      final usernameRef = _firestore.collection('usernames').doc(usernameLower);
      final userRef = _firestore.collection('users').doc(user.uid);

      // Reads must precede writes in a Firestore transaction: check
      // availability first, then claim the username and create the user
      // doc together so the two can never end up out of sync.
      await _firestore.runTransaction((transaction) async {
        final usernameSnapshot = await transaction.get(usernameRef);
        if (usernameSnapshot.exists) {
          throw UsernameTakenException(trimmedUsername);
        }

        transaction.set(usernameRef, {
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.set(userRef, {
          'uid': user.uid,
          'displayName': trimmedName,
          'displayNameLower': trimmedName.toLowerCase(),
          'username': trimmedUsername,
          'usernameLower': usernameLower,
          'email': email.trim(),
          'photoUrl': null,
          'bio': null,
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': null,
          'isOnline': false,
          'fcmToken': null,
        });
      });
    } catch (_) {
      await user.delete();
      rethrow;
    }

    // Best-effort: the account and username are already committed at this
    // point, so a failure here (e.g. rate limiting) shouldn't roll back an
    // otherwise-successful registration — the Verify Email screen's
    // "Resend verification email" button covers this case.
    try {
      await user.sendEmailVerification();
    } catch (_) {
      // Swallowed deliberately — see comment above.
    }
  }

  Future<void> login({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> logout() => _auth.signOut();

  /// Deletes the Firebase Auth account for [expectedUid] specifically —
  /// never just "whoever is currently signed in". A caller can end up
  /// running this after the signed-in user has already changed (see the
  /// identity check in [finishAccountDeletion], which this backs up): if
  /// this blindly deleted `currentUser`, a stale call meant for an account
  /// that's already gone could delete a completely different, currently
  /// live account instead. Requires a recent sign-in — callers must
  /// reauthenticate first (see [ProfileRepository.reauthenticate]) or this
  /// throws `requires-recent-login`. Must run last in the account deletion
  /// sequence: once this succeeds the user is signed out, and any
  /// Firestore/RTDB cleanup still pending would fail auth rule checks.
  Future<void> deleteAccount(String expectedUid) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != expectedUid) return;
    await user.delete();
  }

  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Reloads the current user from Firebase and returns their up-to-date
  /// `emailVerified` status. `authStateChanges()` does not emit on its own
  /// just because verification state flipped server-side, so callers must
  /// explicitly reload and re-check rather than relying on the stream.
  ///
  /// Deliberately reads the result from userChanges() rather than
  /// re-reading currentUser after reload(): on this platform, plain
  /// currentUser kept returning a stale emailVerified within the same
  /// session no matter how many times it was re-read (only a full app
  /// restart picked up the change, which confirms the server-side data
  /// was already correct — this was a client-side caching issue).
  /// userChanges() is the stream Firebase documents as the one that's
  /// guaranteed to emit the refreshed user after reload().
  Future<bool> checkEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final updated = _auth.userChanges().first;
    await user.reload();
    final refreshedUser = await updated.timeout(
      const Duration(seconds: 5),
      onTimeout: () => _auth.currentUser,
    );

    return refreshedUser?.emailVerified ?? false;
  }
}
