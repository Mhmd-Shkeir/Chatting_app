import 'package:firebase_auth/firebase_auth.dart';

String mapAuthError(Object error) {
  if (error is FirebaseAuthException) {
    return error.message ?? 'Authentication failed. Please try again.';
  }
  return 'Something went wrong. Please try again.';
}
