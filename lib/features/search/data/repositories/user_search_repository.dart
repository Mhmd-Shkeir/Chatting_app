import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../authentication/data/models/app_user.dart';

class UserSearchRepository {
  UserSearchRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<List<AppUser>> search(String query) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return const [];

    final snapshot = await _firestore
        .collection('users')
        .where('displayNameLower', isGreaterThanOrEqualTo: trimmed)
        .where('displayNameLower', isLessThan: '$trimmed')
        .limit(20)
        .get();

    final myUid = _auth.currentUser?.uid;

    return snapshot.docs
        .where((doc) => doc.id != myUid)
        .map((doc) => AppUser.fromFirestore(doc.data(), doc.id))
        .toList();
  }
}
