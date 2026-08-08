import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/shared_preferences_provider.dart';
import '../features/notifications/data/background_handler.dart';
import '../firebase_options.dart';
import 'app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    // google-services.json makes Android auto-create the [DEFAULT] app
    // natively before any Dart code runs. Firebase.apps is an unsynced
    // Dart-side cache (always empty on a fresh isolate), so it can't be used
    // to detect this ahead of time — catching core/duplicate-app here is
    // the correct signal that Firebase is already initialized natively.
    if (e.code != 'duplicate-app') rethrow;
  }
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  final sharedPreferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const LuminaChatApp(),
    ),
  );
}
