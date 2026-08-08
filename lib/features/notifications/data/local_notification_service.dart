import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows a system-tray notification while the app is in the foreground —
/// FCM's `notification` payload only auto-displays one when the app is
/// backgrounded or terminated, so a foreground message needs to be shown
/// manually or it's silently dropped.
class LocalNotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init({required void Function(String conversationId) onTap}) async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) onTap(payload);
      },
    );
  }

  /// One notification per conversation (id derived from [conversationId]) —
  /// a second message from the same chat while foregrounded updates the
  /// existing tray entry instead of stacking a new one.
  Future<void> show({
    required String title,
    required String body,
    required String conversationId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'messages',
      'Messages',
      channelDescription: 'New chat messages',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      conversationId.hashCode,
      title,
      body,
      details,
      payload: conversationId,
    );
  }
}
