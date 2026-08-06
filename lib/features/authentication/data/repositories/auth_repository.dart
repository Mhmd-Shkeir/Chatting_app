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
  }

  Future<void> login({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> logout() => _auth.signOut();
}
