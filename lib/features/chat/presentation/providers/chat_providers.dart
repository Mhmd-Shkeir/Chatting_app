import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/models/message.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/translation_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final translationRepositoryProvider = Provider<TranslationRepository>((ref) {
  return TranslationRepository();
});

typedef TranslationRequest = ({
  String conversationId,
  String messageId,
  String text,
  String targetLanguageCode,
});

/// Fire-and-cache: translates [TranslationRequest.text] and writes the
/// result into the message's `translations` map (see ChatRepository.
/// setTranslation). Callers don't need this provider's return value — the
/// live message stream picks up the cached translation once the write
/// lands, which is what actually drives the UI. autoDispose means a bubble
/// that scrolls away before this resolves just cancels cleanly; revisiting
/// it retries (cheaply, if the write already landed by then).
final translationTriggerProvider = FutureProvider.autoDispose
    .family<void, TranslationRequest>((ref, request) async {
      // A bare `ref.read(...future)` (see _TranslatableTextState) doesn't
      // watch this provider, so autoDispose would tear it down the instant
      // this closure yields to the first await — well before the network
      // call finishes — and the write below would then run on an already-
      // disposed ref. keepAlive() holds it open for exactly the duration of
      // this async work; closing the link afterward lets normal autoDispose
      // behavior resume.
      final link = ref.keepAlive();
      try {
        final translated = await ref
            .read(translationRepositoryProvider)
            .translate(
              text: request.text,
              targetLanguageCode: request.targetLanguageCode,
            );
        await ref
            .read(chatRepositoryProvider)
            .setTranslation(
              conversationId: request.conversationId,
              messageId: request.messageId,
              languageCode: request.targetLanguageCode,
              translatedText: translated,
            );
      } catch (error, stackTrace) {
        debugPrint('[translationTriggerProvider] failed for ${request.messageId}: $error');
        debugPrintStack(stackTrace: stackTrace);
        rethrow;
      } finally {
        link.close();
      }
    });

/// Best-effort push trigger shared by text and image sends: looks up the
/// recipient's FCM token (a plain profile field, no extra round trip
/// machinery) and, if they have one registered, asks the push-notify Worker
/// to send it. Every failure mode here is swallowed — a missing token, a
/// signed-out edge case, or the Worker being unreachable must never fail
/// the message send itself, which has already succeeded by the time this
/// runs.
Future<void> _notifyRecipient(
  Ref ref, {
  required String recipientId,
  required String conversationId,
  required String preview,
  required String type,
}) async {
  try {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    final recipient = await ref
        .read(profileRepositoryProvider)
        .getUser(recipientId);
    final recipientToken = recipient?.fcmToken;
    if (recipientToken == null || recipientToken.isEmpty) return;

    final idToken = await authUser.getIdToken();
    if (idToken == null) return;

    final senderName =
        ref.read(currentUserProfileProvider).value?.displayName ??
        'New message';

    await ref
        .read(pushNotificationTriggerProvider)
        .notify(
          idToken: idToken,
          recipientToken: recipientToken,
          senderId: authUser.uid,
          senderName: senderName,
          preview: preview,
          conversationId: conversationId,
          type: type,
        );
  } catch (error, stackTrace) {
    debugPrint('[_notifyRecipient] failed for $recipientId: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

/// In-memory cache of local files for image messages currently
/// sending/failed in this session, so a retry doesn't need the user to
/// re-pick the image. Deliberately not persisted anywhere — if the app is
/// killed before a failed send is retried, the local file reference is
/// gone and retry silently does nothing; the user can just attach the
/// image again as a new message instead.
class PendingImageFiles {
  final Map<String, File> _files = {};

  void put(String messageId, File file) => _files[messageId] = file;
  File? get(String messageId) => _files[messageId];
  void remove(String messageId) => _files.remove(messageId);
}

final pendingImageFilesProvider = Provider<PendingImageFiles>(
  (ref) => PendingImageFiles(),
);

final messagesStreamProvider = StreamProvider.family<List<Message>, String>((
  ref,
  conversationId,
) {
  return ref.watch(chatRepositoryProvider).streamMessages(conversationId);
});

/// The message currently selected as a reply target for the compose bar,
/// if any. Cleared automatically once the reply is sent.
class ReplyingToNotifier extends Notifier<Message?> {
  @override
  Message? build() => null;

  void set(Message? message) => state = message;

  void clear() => state = null;
}

final replyingToProvider = NotifierProvider<ReplyingToNotifier, Message?>(
  ReplyingToNotifier.new,
);

class SendMessageController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> send({
    required String conversationId,
    required List<String> recipientIds,
    required String text,
    ReplyPreview? replyTo,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            conversationId: conversationId,
            recipientIds: recipientIds,
            text: trimmed,
            replyTo: replyTo,
          );
      for (final recipientId in recipientIds) {
        unawaited(
          _notifyRecipient(
            ref,
            recipientId: recipientId,
            conversationId: conversationId,
            preview: trimmed,
            type: 'text',
          ),
        );
      }
    });
  }
}

final sendMessageControllerProvider =
    AsyncNotifierProvider<SendMessageController, void>(
      SendMessageController.new,
    );

class SendImageMessageController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> send({
    required String conversationId,
    required List<String> recipientIds,
    required File file,
    ReplyPreview? replyTo,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final messageId = await ref
          .read(chatRepositoryProvider)
          .sendPendingImageMessage(conversationId, replyTo: replyTo);
      ref.read(pendingImageFilesProvider).put(messageId, file);
      await _upload(
        conversationId: conversationId,
        recipientIds: recipientIds,
        messageId: messageId,
        file: file,
      );
    });
  }

  /// Re-attempts a failed send using the same local file, if this session
  /// still has it cached (see [PendingImageFiles]).
  Future<void> retry({
    required String conversationId,
    required List<String> recipientIds,
    required String messageId,
  }) async {
    final file = ref.read(pendingImageFilesProvider).get(messageId);
    if (file == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(chatRepositoryProvider)
          .retryImageMessage(
            conversationId: conversationId,
            messageId: messageId,
          );
      await _upload(
        conversationId: conversationId,
        recipientIds: recipientIds,
        messageId: messageId,
        file: file,
      );
    });
  }

  Future<void> _upload({
    required String conversationId,
    required List<String> recipientIds,
    required String messageId,
    required File file,
  }) async {
    try {
      final url = await ref
          .read(imageKitRepositoryProvider)
          .uploadImage(
            file,
            fileName:
                'chat_${conversationId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
      await ref
          .read(chatRepositoryProvider)
          .completeImageMessage(
            conversationId: conversationId,
            messageId: messageId,
            recipientIds: recipientIds,
            imageUrl: url,
          );
      ref.read(pendingImageFilesProvider).remove(messageId);
      for (final recipientId in recipientIds) {
        unawaited(
          _notifyRecipient(
            ref,
            recipientId: recipientId,
            conversationId: conversationId,
            preview: 'Photo',
            type: 'image',
          ),
        );
      }
    } catch (_) {
      await ref
          .read(chatRepositoryProvider)
          .failImageMessage(
            conversationId: conversationId,
            messageId: messageId,
          );
      rethrow;
    }
  }
}

final sendImageMessageControllerProvider =
    AsyncNotifierProvider<SendImageMessageController, void>(
      SendImageMessageController.new,
    );

/// Mirrors [SendImageMessageController] for voice messages — same
/// pending-doc-then-upload-then-complete shape, same failure/retry path,
/// and the recorded file is cached in [pendingImageFilesProvider] too
/// (that class is just a messageId -> File map; nothing about it is
/// actually image-specific despite the name).
class SendVoiceMessageController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> send({
    required String conversationId,
    required List<String> recipientIds,
    required File file,
    required int durationSeconds,
    ReplyPreview? replyTo,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final messageId = await ref
          .read(chatRepositoryProvider)
          .sendPendingVoiceMessage(
            conversationId,
            durationSeconds: durationSeconds,
            replyTo: replyTo,
          );
      ref.read(pendingImageFilesProvider).put(messageId, file);
      await _upload(
        conversationId: conversationId,
        recipientIds: recipientIds,
        messageId: messageId,
        file: file,
      );
    });
  }

  Future<void> retry({
    required String conversationId,
    required List<String> recipientIds,
    required String messageId,
  }) async {
    final file = ref.read(pendingImageFilesProvider).get(messageId);
    if (file == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(chatRepositoryProvider)
          .retryVoiceMessage(
            conversationId: conversationId,
            messageId: messageId,
          );
      await _upload(
        conversationId: conversationId,
        recipientIds: recipientIds,
        messageId: messageId,
        file: file,
      );
    });
  }

  Future<void> _upload({
    required String conversationId,
    required List<String> recipientIds,
    required String messageId,
    required File file,
  }) async {
    try {
      final url = await ref
          .read(imageKitRepositoryProvider)
          .uploadImage(
            file,
            fileName:
                'chat_voice_${conversationId}_${DateTime.now().millisecondsSinceEpoch}.m4a',
          );
      await ref
          .read(chatRepositoryProvider)
          .completeVoiceMessage(
            conversationId: conversationId,
            messageId: messageId,
            recipientIds: recipientIds,
            audioUrl: url,
          );
      ref.read(pendingImageFilesProvider).remove(messageId);
      for (final recipientId in recipientIds) {
        unawaited(
          _notifyRecipient(
            ref,
            recipientId: recipientId,
            conversationId: conversationId,
            preview: 'Voice message',
            type: 'voice',
          ),
        );
      }
    } catch (_) {
      await ref
          .read(chatRepositoryProvider)
          .failVoiceMessage(conversationId: conversationId, messageId: messageId);
      rethrow;
    }
  }
}

final sendVoiceMessageControllerProvider =
    AsyncNotifierProvider<SendVoiceMessageController, void>(
      SendVoiceMessageController.new,
    );
