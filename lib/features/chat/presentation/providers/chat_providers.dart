import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/models/message.dart';
import '../../data/repositories/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

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
    required String recipientId,
    required String text,
    ReplyPreview? replyTo,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref
          .read(chatRepositoryProvider)
          .sendMessage(
            conversationId: conversationId,
            recipientId: recipientId,
            text: trimmed,
            replyTo: replyTo,
          );
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
    required String recipientId,
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
        recipientId: recipientId,
        messageId: messageId,
        file: file,
      );
    });
  }

  /// Re-attempts a failed send using the same local file, if this session
  /// still has it cached (see [PendingImageFiles]).
  Future<void> retry({
    required String conversationId,
    required String recipientId,
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
        recipientId: recipientId,
        messageId: messageId,
        file: file,
      );
    });
  }

  Future<void> _upload({
    required String conversationId,
    required String recipientId,
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
            recipientId: recipientId,
            imageUrl: url,
          );
      ref.read(pendingImageFilesProvider).remove(messageId);
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
