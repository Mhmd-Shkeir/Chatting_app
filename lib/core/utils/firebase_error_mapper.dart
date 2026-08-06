import 'package:firebase_auth/firebase_auth.dart';

import '../errors/username_taken_exception.dart';

String mapAuthError(Object error) {
  if (error is FirebaseAuthException) {
    return error.message ?? 'Authentication failed. Please try again.';
  }
  if (error is UsernameTakenException) {
    return 'That username is already taken.';
  }
  return 'Something went wrong. Please try again.';
}
