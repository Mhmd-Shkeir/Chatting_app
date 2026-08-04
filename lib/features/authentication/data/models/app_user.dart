import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.displayNameLower,
    required this.email,
    this.photoUrl,
    this.bio,
    this.createdAt,
    this.lastSeen,
    this.isOnline = false,
  });

  final String uid;
  final String displayName;
  final String displayNameLower;
  final String email;
  final String? photoUrl;
  final String? bio;
  final DateTime? createdAt;
  final DateTime? lastSeen;
  final bool isOnline;

  factory AppUser.fromFirestore(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      displayName: data['displayName'] as String? ?? '',
      displayNameLower: data['displayNameLower'] as String? ?? '',
      email: data['email'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      bio: data['bio'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      isOnline: data['isOnline'] as bool? ?? false,
    );
  }
}
