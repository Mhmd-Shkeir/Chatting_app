import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../app/router.dart';
import '../../../../core/config/notification_config.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/local_notification_service.dart';
import '../../data/repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  final service = LocalNotificationService();
  unawaited(
    service.init(
      onTap: (conversationId) =>
          ref.read(routerProvider).push('/chat/$conversationId'),
    ),
  );
  return service;
});

/// Watched once at the app root (mirrors presenceTrackerProvider): requests
/// notification permission, registers this device's FCM token against the
/// signed-in user's profile, keeps it fresh on rotation, and wires
/// foreground display + tap-to-open (background/terminated taps go through
/// the same onNotificationOpenedApp/getInitialMessage path). Has no value
/// of its own — it's activated by being watched, not by being read.
final notificationTrackerProvider = Provider<void>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  final localNotifications = ref.watch(localNotificationServiceProvider);
  final isLoggedIn = ref.watch(authStateChangesProvider).value != null;

  if (!isLoggedIn) return;

  unawaited(() async {
    await repository.requestPermission();
    final token = await repository.getToken();
    if (token != null) {
      await ref.read(profileRepositoryProvider).updateFcmToken(token);
    }
  }());

  final refreshSub = repository.onTokenRefresh.listen((token) {
    ref.read(profileRepositoryProvider).updateFcmToken(token);
  });

  final foregroundSub = repository.onForegroundMessage.listen((message) {
    final notification = message.notification;
    final conversationId = message.data['conversationId'];
    if (notification == null || conversationId == null) return;
    localNotifications.show(
      title: notification.title ?? '',
      body: notification.body ?? '',
      conversationId: conversationId,
    );
  });

  final openedSub = repository.onNotificationOpenedApp.listen((message) {
    final conversationId = message.data['conversationId'];
    if (conversationId != null) {
      ref.read(routerProvider).push('/chat/$conversationId');
    }
  });

  repository.getInitialMessage().then((message) {
    final conversationId = message?.data['conversationId'];
    if (conversationId != null) {
      ref.read(routerProvider).push('/chat/$conversationId');
    }
  });

  ref.onDispose(() {
    refreshSub.cancel();
    foregroundSub.cancel();
    openedSub.cancel();
  });
});

/// Fire-and-forget: asks the push-notify Worker to send a single FCM push
/// for a message that was just successfully written to Firestore. A failed
/// or skipped push must never fail the message send itself, so every
/// failure mode here is swallowed (after logging) rather than rethrown.
class PushNotificationTrigger {
  PushNotificationTrigger({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<void> notify({
    required String idToken,
    required String recipientToken,
    required String senderId,
    required String senderName,
    required String preview,
    required String conversationId,
    required String type,
  }) async {
    try {
      await _client
          .post(
            Uri.parse(pushNotifyEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'token': recipientToken,
              'title': senderName,
              'body': preview,
              'conversationId': conversationId,
              'senderId': senderId,
              'type': type,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Best-effort — see class doc comment.
    }
  }
}

final pushNotificationTriggerProvider = Provider<PushNotificationTrigger>((
  ref,
) {
  return PushNotificationTrigger();
});
