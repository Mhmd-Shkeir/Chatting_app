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
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final displayNameLower = trimmed.toLowerCase();
    final usernameLower =
        (trimmed.startsWith('@') ? trimmed.substring(1) : trimmed).toLowerCase();

    final results = await Future.wait([
      // '' sorts after every valid Unicode character, so this range
      // matches every displayNameLower that starts with the query. The
      // previous version omitted it, making the range [x, x) — mathematically
      // empty, so this query has never actually returned a result.
      _firestore
          .collection('users')
          .where('displayNameLower', isGreaterThanOrEqualTo: displayNameLower)
          .where('displayNameLower', isLessThan: '$displayNameLower')
          .limit(20)
          .get(),
      if (usernameLower.isNotEmpty)
        _firestore
            .collection('users')
            .where('usernameLower', isEqualTo: usernameLower)
            .limit(1)
            .get(),
    ]);

    final myUid = _auth.currentUser?.uid;
    final seen = <String>{};
    final users = <AppUser>[];

    for (final snapshot in results) {
      for (final doc in snapshot.docs) {
        if (doc.id == myUid) continue;
        if (!seen.add(doc.id)) continue;
        users.add(AppUser.fromFirestore(doc.data(), doc.id));
      }
    }

    return users;
  }
}
