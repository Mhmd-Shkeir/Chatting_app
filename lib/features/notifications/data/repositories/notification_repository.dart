import 'package:firebase_messaging/firebase_messaging.dart';

/// Thin wrapper around [FirebaseMessaging] — the token lifecycle (fetch,
/// persist, refresh) and message-stream wiring live in
/// notificationTrackerProvider; this class just exposes what it needs.
class NotificationRepository {
  NotificationRepository({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  /// No-op on Android below 13 (no runtime prompt exists there); triggers
  /// the system permission dialog on Android 13+ and iOS.
  Future<void> requestPermission() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  Future<String?> getToken() => _messaging.getToken();

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Fires while the app is in the foreground. FCM does not auto-display a
  /// system notification for these — the caller must show one itself (see
  /// LocalNotificationService).
  Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;

  /// Fires when the user taps a notification that was shown while the app
  /// was backgrounded (not terminated).
  Stream<RemoteMessage> get onNotificationOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  /// The notification that launched the app from a fully terminated state,
  /// if any — null on a normal cold start.
  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();
}
