import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/username_taken_exception.dart';
import '../../../../core/localization/app_language.dart';
import '../../../authentication/data/models/app_user.dart';

class ProfileRepository {
  ProfileRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<AppUser?> watchUser(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map(
          (doc) =>
              doc.exists ? AppUser.fromFirestore(doc.data()!, doc.id) : null,
        );
  }

  /// A one-off read, for callers (like the push-notification trigger) that
  /// just need a snapshot of another user's profile and shouldn't stand up
  /// a live subscription for it.
  Future<AppUser?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists ? AppUser.fromFirestore(doc.data()!, doc.id) : null;
  }

  Future<void> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final trimmed = displayName.trim();
    await user.updateDisplayName(trimmed);
    await _firestore.collection('users').doc(user.uid).update({
      'displayName': trimmed,
      'displayNameLower': trimmed.toLowerCase(),
    });
  }

  /// [photoUrl] is an ImageKit CDN URL, or null to reset to the default
  /// initials avatar (see UserAvatar).
  Future<void> updatePhotoUrl(String? photoUrl) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'photoUrl': photoUrl,
    });
  }

  Future<void> updatePreferredLanguage(AppLanguage language) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'preferredLanguage': language.code,
    });
  }

  /// Registers (or clears, on sign-out/token invalidation) this device's FCM
  /// registration token so other users' sends can look it up to push a
  /// notification. Not the message-read source of truth for anything else —
  /// purely a delivery address.
  Future<void> updateFcmToken(String? token) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'fcmToken': token,
    });
  }

  /// Firebase requires a recent sign-in before it will allow deleting the
  /// account — this re-proves identity with their current password so
  /// AuthRepository.deleteAccount() doesn't throw requires-recent-login.
  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) return;

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  /// Replaces the account's Firestore doc with a minimal stub instead of
  /// deleting it outright. Conversations and messages reference this uid
  /// and are deliberately left untouched, so a hard delete would leave
  /// other participants looking at a name that resolves to nothing — this
  /// way they see "Deleted Account" instead. Must run before
  /// AuthRepository.deleteAccount(): this write requires request.auth to
  /// still be the account being deleted.
  Future<void> tombstoneUserDoc() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'displayName': 'Deleted Account',
      'displayNameLower': 'deleted account',
      'email': '',
      'username': null,
      'usernameLower': null,
      'photoUrl': null,
      'bio': null,
      'preferredLanguage': null,
      'isOnline': false,
      'lastSeen': null,
      'fcmToken': null,
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });

    // set() above resolves as soon as the write is queued in Firestore's
    // local cache — not once the server has actually accepted it. If the
    // Auth account gets deleted (invalidating request.auth for this uid)
    // before this specific write has really reached the backend, the
    // server-side sync silently gets rejected by security rules and the
    // tombstone is lost forever, even though the deleting device's own
    // local cache still shows it as if it had worked. Waiting here closes
    // that race — the caller must not proceed to delete the Auth account
    // until this returns. Bounded with a timeout so deleting while offline
    // fails fast with a clear error instead of leaving the delete dialog's
    // spinner running forever — the queued write isn't cancelled by this
    // timeout and can still sync later on its own, which is exactly the
    // "tombstoned but not yet Auth-deleted" state router.dart's self-heal
    // is designed to finish on a later launch.
    await _firestore.waitForPendingWrites().timeout(
      const Duration(seconds: 15),
    );
  }

  /// For an existing account claiming a username for the first time
  /// (onboarding), as opposed to [AuthRepository.register] which claims one
  /// as part of creating a brand-new account.
  Future<void> claimUsername(String username) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final trimmedUsername = username.trim();
    final usernameLower = trimmedUsername.toLowerCase();
    final usernameRef = _firestore.collection('usernames').doc(usernameLower);
    final userRef = _firestore.collection('users').doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final usernameSnapshot = await transaction.get(usernameRef);
      if (usernameSnapshot.exists) {
        throw UsernameTakenException(trimmedUsername);
      }

      transaction.set(usernameRef, {
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.update(userRef, {
        'username': trimmedUsername,
        'usernameLower': usernameLower,
      });
    });
  }
}
