import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/localization/app_language.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.displayNameLower,
    required this.email,
    this.username,
    this.usernameLower,
    this.photoUrl,
    this.bio,
    this.createdAt,
    this.lastSeen,
    this.isOnline = false,
    this.deleted = false,
    this.preferredLanguage = AppLanguage.english,
    this.fcmToken,
  });

  final String uid;
  final String displayName;
  final String displayNameLower;
  final String email;
  final String? username;
  final String? usernameLower;
  final String? photoUrl;
  final String? bio;
  final DateTime? createdAt;
  final DateTime? lastSeen;
  final bool isOnline;
  final bool deleted;
  final AppLanguage preferredLanguage;

  /// This device's current FCM registration token, if any — see
  /// ProfileRepository.updateFcmToken. Used only to address a push
  /// notification to this user; never displayed or compared for identity.
  final String? fcmToken;

  bool get hasUsername => username != null && username!.isNotEmpty;

  factory AppUser.fromFirestore(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      displayName: data['displayName'] as String? ?? '',
      displayNameLower: data['displayNameLower'] as String? ?? '',
      email: data['email'] as String? ?? '',
      username: data['username'] as String?,
      usernameLower: data['usernameLower'] as String?,
      photoUrl: data['photoUrl'] as String?,
      bio: data['bio'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      isOnline: data['isOnline'] as bool? ?? false,
      deleted: data['deleted'] as bool? ?? false,
      preferredLanguage: AppLanguage.fromCode(
        data['preferredLanguage'] as String?,
      ),
      fcmToken: data['fcmToken'] as String?,
    );
  }
}
