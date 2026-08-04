import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user!;
    final trimmedName = displayName.trim();

    try {
      await user.updateDisplayName(trimmedName);
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'displayName': trimmedName,
        'displayNameLower': trimmedName.toLowerCase(),
        'email': email.trim(),
        'photoUrl': null,
        'bio': null,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': null,
        'isOnline': false,
        'fcmToken': null,
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
