import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
}
