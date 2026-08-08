import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../firebase_options.dart';

/// Runs in a separate background isolate when a push arrives while the app
/// is backgrounded or terminated. Android's FCM SDK already auto-displays
/// the `notification` payload in the system tray with no code needed here —
/// this handler exists only because firebase_messaging requires one to be
/// registered, and re-initializes Firebase since a background isolate
/// doesn't share the main isolate's already-initialized instance.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
}
