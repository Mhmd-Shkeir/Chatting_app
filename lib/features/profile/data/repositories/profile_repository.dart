import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/username_taken_exception.dart';
import '../../../authentication/data/models/app_user.dart';

class ProfileRepository {
  ProfileRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<AppUser?> watchUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map(
          (doc) => doc.exists ? AppUser.fromFirestore(doc.data()!, doc.id) : null,
        );
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
