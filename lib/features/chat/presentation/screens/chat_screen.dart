import 'dart:async';
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/localization/app_language.dart';
import '../../../../core/utils/presence_formatter.dart';
import '../../../../core/widgets/photo_source_sheet.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../authentication/presentation/providers/presence_providers.dart';
import '../../../conversations/data/models/conversation.dart';
import '../../../conversations/presentation/providers/conversation_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/models/message.dart';
import '../providers/chat_providers.dart';
import '../widgets/message_bubble.dart';
import '../widgets/reply_preview_strip.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _listController = ScrollController();
  // Keyed per message id so a tap on a reply preview can scroll straight
  // to the original bubble when it's already built (the common case —
  // most replies point at something nearby).
  final _messageKeys = <String, GlobalKey>{};
  String? _highlightedMessageId;
  Timer? _highlightTimer;
  bool _showEmojiPicker = false;

  final _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(chatRepositoryProvider)
          .markConversationRead(widget.conversationId),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _listController.dispose();
    _highlightTimer?.cancel();
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String messageId) =>
      _messageKeys.putIfAbsent(messageId, () => GlobalKey());

  // Rough average bubble height used only to jump near a message that
  // isn't built yet (too far outside the list's cache window) so it gets
  // laid out — [_scrollToMessage] then fine-tunes onto its exact position.
  static const _estimatedItemExtent = 80.0;

  void _scrollToMessage(String messageId, List<Message> messages) {
    final builtContext = _messageKeys[messageId]?.currentContext;
    if (builtContext != null) {
      _settleOnMessage(builtContext, messageId);
      return;
    }

    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1 || !_listController.hasClients) return;

    final estimatedOffset = (index * _estimatedItemExtent).clamp(
      0.0,
      _listController.position.maxScrollExtent,
    );
    _listController.jumpTo(estimatedOffset);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _messageKeys[messageId]?.currentContext;
      if (context != null) {
        _settleOnMessage(context, messageId);
      } else {
        // Estimate landed close but not exact — still flag the highlight
        // rather than leaving the user without any feedback.
        _flagHighlighted(messageId);
      }
    });
  }

  void _settleOnMessage(BuildContext context, String messageId) {
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.5,
    );
    _flagHighlighted(messageId);
  }

  void _flagHighlighted(String messageId) {
    _highlightTimer?.cancel();
    setState(() => _highlightedMessageId = messageId);
    _highlightTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _highlightedMessageId = null);
    });
  }

  Conversation? _findConversation(List<Conversation>? conversations) {
    if (conversations == null) return null;
    for (final conversation in conversations) {
      if (conversation.id == widget.conversationId) return conversation;
    }
    return null;
  }

  String? _translationTarget(AppLanguage mine, AppLanguage other) {
    return mine == other ? null : mine.code;
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(authStateChangesProvider).value?.uid;
    final conversations = ref.watch(conversationsStreamProvider).value;
    final conversation = _findConversation(conversations);
    final otherUid = (myUid != null && conversation != null)
        ? conversation.otherParticipantId(myUid)
        : null;
    final otherProfile = otherUid != null
        ? ref.watch(userProfileProvider(otherUid)).value
        : null;
    final myProfile = ref.watch(currentUserProfileProvider).value;
    // Only translate incoming text when the two participants' preferred
    // languages actually differ — a null here means "don't translate",
    // consumed by MessageBubble below.
    final translateToLanguageCode = (myProfile != null && otherProfile != null)
        ? _translationTarget(
            myProfile.preferredLanguage,
            otherProfile.preferredLanguage,
          )
        : null;
    // Same reasoning as ConversationTile: participantNames is a frozen
    // snapshot that never learns about account deletion, so that has to
    // come from the live per-uid lookup instead.
    final isDeleted = otherProfile?.deleted ?? false;
    final otherName = isDeleted
        ? 'Deleted Account'
        : (myUid != null && conversation != null)
        ? conversation.otherParticipantName(myUid)
        : 'Chat';

    final messagesAsync = ref.watch(
      messagesStreamProvider(widget.conversationId),
    );
    final sendState = ref.watch(sendMessageControllerProvider);
    final replyingTo = ref.watch(replyingToProvider);
    // A deleted account must never be presence-listened-to at all, let
    // alone shown as online or with a last-seen time.
    final presence = (otherUid != null && !isDeleted)
        ? ref.watch(presenceStatusProvider(otherUid)).value
        : null;
    final otherUsername = otherProfile?.username;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            UserAvatar(
              photoUrl: otherProfile?.photoUrl,
              displayName: otherName,
              radius: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(otherName, overflow: TextOverflow.ellipsis),
                      ),
                      if (otherUsername != null &&
                          otherUsername.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '@$otherUsername',
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (presence != null)
                    Text(
                      presence.isOnline
                          ? 'Online'
                          : formatLastSeen(presence.lastSeen),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Something went wrong: $error')),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Say hello.'),
                  );
                }
                if (otherUid != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref
                        .read(chatRepositoryProvider)
                        .markMessagesRead(
                          conversationId: widget.conversationId,
                          otherUid: otherUid,
                        );
                  });
                }
                return Scrollbar(
                  controller: _listController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _listController,
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    // Wider than the default cache window so a jump-to a
                    // message that isn't built yet (see _scrollToMessage)
                    // lands close enough for its bubble to already exist.
                    cacheExtent: 2000,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return MessageBubble(
                        key: _keyFor(message.id),
                        message: message,
                        isMine: message.senderId == myUid,
                        conversationId: widget.conversationId,
                        recipientId: otherUid ?? '',
                        currentUserId: myUid ?? '',
                        otherUserName: otherName,
                        onReplyTap: (id) => _scrollToMessage(id, messages),
                        isHighlighted: message.id == _highlightedMessageId,
                        translateToLanguageCode: translateToLanguageCode,
                      );
                    },
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (replyingTo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ReplyPreviewStrip(
                        senderLabel: replyingTo.senderId == myUid
                            ? 'You'
                            : otherName,
                        preview: ReplyPreview.fromMessage(
                          replyingTo,
                        ).previewLabel,
                        onCancel: () =>
                            ref.read(replyingToProvider.notifier).clear(),
                      ),
                    ),
                  if (_isRecording)
                    _buildRecordingRow(context)
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.image_outlined),
                          onPressed: otherUid == null
                              ? null
                              : () => _sendImage(otherUid),
                        ),
                        IconButton(
                          icon: Icon(
                            _showEmojiPicker
                                ? Icons.keyboard
                                : Icons.emoji_emotions_outlined,
                          ),
                          onPressed: _toggleEmojiPicker,
                        ),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: TextField(
                              controller: _textController,
                              minLines: 1,
                              maxLines: 5,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                hintText: 'Message',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              textInputAction: TextInputAction.send,
                              onTap: () {
                                if (_showEmojiPicker) {
                                  setState(() => _showEmojiPicker = false);
                                }
                              },
                              onSubmitted: (_) => _send(otherUid),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _textController,
                          builder: (context, value, _) {
                            if (value.text.trim().isEmpty) {
                              return IconButton.filled(
                                icon: const Icon(Icons.mic),
                                onPressed: otherUid == null
                                    ? null
                                    : _startRecording,
                              );
                            }
                            return IconButton.filled(
                              icon: sendState.isLoading
                                  ? SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              onPressed: sendState.isLoading
                                  ? null
                                  : () => _send(otherUid),
                            );
                          },
                        ),
                      ],
                    ),
                  if (_showEmojiPicker)
                    SizedBox(
                      height: 260,
                      child: EmojiPicker(
                        onEmojiSelected: (category, emoji) {
                          final selection = _textController.selection;
                          final text = _textController.text;
                          final insertAt = selection.start < 0
                              ? text.length
                              : selection.start;
                          final newText = text.replaceRange(
                            insertAt,
                            selection.end < 0 ? insertAt : selection.end,
                            emoji.emoji,
                          );
                          _textController.value = TextEditingValue(
                            text: newText,
                            selection: TextSelection.collapsed(
                              offset: insertAt + emoji.emoji.length,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingRow(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final minutes = (_recordSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordSeconds % 60).toString().padLeft(2, '0');
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.delete_outline, color: colorScheme.error),
          onPressed: _cancelRecording,
        ),
        Icon(Icons.fiber_manual_record, color: colorScheme.error, size: 14),
        const SizedBox(width: 8),
        Text('Recording $minutes:$seconds'),
        const Spacer(),
        IconButton.filled(icon: const Icon(Icons.send), onPressed: _stopAndSendRecording),
      ],
    );
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _showEmojiPicker = true);
  }

  Future<void> _send(String? recipientId) async {
    if (recipientId == null) return;
    final text = _textController.text;
    final replyingTo = ref.read(replyingToProvider);
    _textController.clear();
    ref.read(replyingToProvider.notifier).clear();
    await ref
        .read(sendMessageControllerProvider.notifier)
        .send(
          conversationId: widget.conversationId,
          recipientId: recipientId,
          text: text,
          replyTo: replyingTo == null
              ? null
              : ReplyPreview.fromMessage(replyingTo),
        );
  }

  Future<void> _sendImage(String recipientId) async {
    final action = await showModalBottomSheet<PhotoSourceAction>(
      context: context,
      builder: (context) => const PhotoSourceSheet(),
    );
    if (action == null || !mounted) return;

    final picked = await ImagePicker().pickImage(
      source: action == PhotoSourceAction.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    final replyingTo = ref.read(replyingToProvider);
    ref.read(replyingToProvider.notifier).clear();
    await ref
        .read(sendImageMessageControllerProvider.notifier)
        .send(
          conversationId: widget.conversationId,
          recipientId: recipientId,
          file: File(picked.path),
          replyTo: replyingTo == null
              ? null
              : ReplyPreview.fromMessage(replyingTo),
        );
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Microphone permission is needed to record voice messages. '
              'Enable it in the app\'s system settings.',
            ),
          ),
        );
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/lumina_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);

    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
      _recordingPath = path;
      _showEmojiPicker = false;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    await _recorder.stop();
    final path = _recordingPath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordingPath = null;
    });
  }

  Future<void> _stopAndSendRecording() async {
    final recipientId = _findConversation(
      ref.read(conversationsStreamProvider).value,
    )?.otherParticipantId(ref.read(authStateChangesProvider).value?.uid ?? '');
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    final duration = _recordSeconds;
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordingPath = null;
    });

    final resolvedPath = path ?? _recordingPath;
    if (resolvedPath == null || recipientId == null || duration < 1) return;

    final replyingTo = ref.read(replyingToProvider);
    ref.read(replyingToProvider.notifier).clear();
    await ref
        .read(sendVoiceMessageControllerProvider.notifier)
        .send(
          conversationId: widget.conversationId,
          recipientId: recipientId,
          file: File(resolvedPath),
          durationSeconds: duration,
          replyTo: replyingTo == null
              ? null
              : ReplyPreview.fromMessage(replyingTo),
        );
  }
}
