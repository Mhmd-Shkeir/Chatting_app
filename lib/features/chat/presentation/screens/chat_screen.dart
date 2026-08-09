import 'dart:async';
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/utils/presence_formatter.dart';
import '../../../../core/widgets/photo_source_sheet.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../authentication/presentation/providers/presence_providers.dart';
import '../../../conversations/presentation/providers/conversation_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/models/message.dart';
import '../providers/chat_providers.dart';
import '../providers/e2ee_providers.dart';
import '../widgets/message_bubble.dart';
import '../widgets/reply_preview_strip.dart';

/// Null when nobody else is typing. For a direct chat there's only ever one
/// other person, so the label is always the same fixed string; a group
/// names who, since which of several people could matter.
String? _typingLabel(Set<String> typingUids, bool isGroup, String Function(String uid) nameFor) {
  if (typingUids.isEmpty) return null;
  if (!isGroup) return 'typing…';

  final names = typingUids.map(nameFor).toList();
  if (names.length == 1) return '${names[0]} is typing…';
  if (names.length == 2) return '${names[0]} and ${names[1]} are typing…';
  return '${names[0]} and ${names.length - 1} others are typing…';
}

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
  Message? _editingMessage;

  final _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _recordingPath;

  // How long to wait after the last keystroke before clearing the typing
  // flag — matches the common "few seconds of silence" convention rather
  // than clearing the instant the field is blurred.
  static const _typingIdleDuration = Duration(seconds: 3);
  Timer? _typingIdleTimer;
  bool _isTypingActive = false;

  // Independent of the writer's own idle timer above — this is the reader
  // side's staleness check, a periodic rebuild so a typing entry ages out
  // of the display within _typingStaleAfter even if the person who was
  // typing never sent an explicit "stopped" write (app killed, connection
  // dropped before onDisconnect could fire, an out-of-order write, etc.).
  // A stream alone can't do this — it only emits on a data change, not
  // merely because time passed.
  static const _typingStaleAfter = Duration(seconds: 6);
  Timer? _typingStalenessTicker;

  // uid -> the display name inserted for it, so send-time can confirm the
  // mention text wasn't deleted afterward (see _send) without tracking
  // precise text ranges through every subsequent edit.
  final Map<String, String> _draftMentions = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(chatRepositoryProvider)
          .markConversationRead(widget.conversationId),
    );
    _typingStalenessTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _listController.dispose();
    _highlightTimer?.cancel();
    _recordTimer?.cancel();
    _recorder.dispose();
    _typingIdleTimer?.cancel();
    _typingStalenessTicker?.cancel();
    if (_isTypingActive) {
      ref
          .read(typingRepositoryProvider)
          .setTyping(conversationId: widget.conversationId, isTyping: false);
    }
    super.dispose();
  }

  void _onMessageTextChanged(String text) {
    // Redraws the @-mention suggestion row, which reads cursor/text state
    // straight off _textController in build() rather than its own field.
    setState(() {});

    final hasText = text.trim().isNotEmpty;
    _typingIdleTimer?.cancel();
    if (!hasText) {
      _stopTyping();
      return;
    }
    if (!_isTypingActive) {
      _isTypingActive = true;
      ref
          .read(typingRepositoryProvider)
          .setTyping(conversationId: widget.conversationId, isTyping: true);
    }
    _typingIdleTimer = Timer(_typingIdleDuration, _stopTyping);
  }

  void _stopTyping() {
    _typingIdleTimer?.cancel();
    if (!_isTypingActive) return;
    _isTypingActive = false;
    ref
        .read(typingRepositoryProvider)
        .setTyping(conversationId: widget.conversationId, isTyping: false);
  }

  /// The @-mention word currently being typed at the cursor, if any — null
  /// whenever the cursor isn't sitting right after an unfinished "@word"
  /// (no space/newline between the @ and the cursor).
  String? _activeMentionQuery() {
    final selection = _textController.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;
    final cursor = selection.baseOffset;
    if (cursor <= 0) return null;

    final upToCursor = _textController.text.substring(0, cursor);
    final atIndex = upToCursor.lastIndexOf('@');
    if (atIndex == -1) return null;

    final between = upToCursor.substring(atIndex + 1);
    if (between.contains(' ') || between.contains('\n')) return null;
    return between;
  }

  void _selectMention(String uid, String displayName) {
    final text = _textController.text;
    final cursor = _textController.selection.baseOffset;
    final upToCursor = text.substring(0, cursor);
    final atIndex = upToCursor.lastIndexOf('@');
    if (atIndex == -1) return;

    final newText = '${text.substring(0, atIndex)}@$displayName ${text.substring(cursor)}';
    final newCursor = atIndex + displayName.length + 2;
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    _draftMentions[uid] = displayName;
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

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(authStateChangesProvider).value?.uid;
    // Deliberately not conversationsStreamProvider (which hides a
    // cleared/deleted-from-list conversation) — this screen is explicitly
    // open on a known conversationId and must keep resolving participants
    // regardless of list visibility.
    final conversation = ref
        .watch(conversationDetailProvider(widget.conversationId))
        .value;
    final isGroup = conversation?.isGroup ?? false;
    // Every other participant — one person in a direct conversation, any
    // number of them in a group. Feeds every send path below.
    final recipientIds = (myUid != null && conversation != null)
        ? conversation.otherParticipantIds(myUid)
        : const <String>[];
    final otherUid = (!isGroup && myUid != null && conversation != null)
        ? conversation.otherParticipantId(myUid)
        : null;
    final otherProfile = otherUid != null
        ? ref.watch(userProfileProvider(otherUid)).value
        : null;
    final myProfile = ref.watch(currentUserProfileProvider).value;
    // Consumed by MessageBubble, which does its own per-sender comparison
    // (a group can have senders in different languages from the viewer).
    final myLanguageCode = myProfile?.preferredLanguage.code;
    // Same reasoning as ConversationTile: participantNames is a frozen
    // snapshot that never learns about account deletion, so that has to
    // come from the live per-uid lookup instead. Group-only concept aside,
    // this only applies to direct conversations.
    final isDeleted = otherProfile?.deleted ?? false;
    final otherName = isDeleted
        ? 'Deleted Account'
        : (myUid != null && conversation != null)
        ? conversation.otherParticipantName(myUid)
        : 'Chat';
    final participantNames = conversation?.participantNames ?? const <String, String>{};
    String nameFor(String uid) =>
        (myUid != null && uid == myUid) ? 'You' : (participantNames[uid] ?? 'Unknown');
    final headerTitle = isGroup ? (conversation?.groupName ?? 'Group') : otherName;

    final messagesAsync = ref.watch(
      messagesStreamProvider(widget.conversationId),
    );
    final sendState = ref.watch(sendMessageControllerProvider);
    final replyingTo = ref.watch(replyingToProvider);
    // A deleted account must never be presence-listened-to at all, let
    // alone shown as online or with a last-seen time. Groups have no single
    // presence to show at all.
    final presence = (otherUid != null && !isDeleted)
        ? ref.watch(presenceStatusProvider(otherUid)).value
        : null;
    final otherUsername = otherProfile?.username;
    // Basic E2EE MVP — 1:1 text only (see E2eeRepository's doc comment for
    // exactly what this does and doesn't protect against).
    final isE2eeEnabled = !isGroup && (conversation?.e2eeEnabled ?? false);
    final typingTimestamps =
        ref.watch(typingTimestampsProvider(widget.conversationId)).value ?? const {};
    final typingStaleCutoff =
        DateTime.now().millisecondsSinceEpoch - _typingStaleAfter.inMilliseconds;
    final typingUids = typingTimestamps.entries
        .where((entry) => entry.value >= typingStaleCutoff)
        .map((entry) => entry.key)
        .toSet();
    final typingLabel = _typingLabel(typingUids, isGroup, nameFor);

    // @mentions only make sense in a group — a direct chat has nobody else
    // to disambiguate, the message is already unambiguously "to them".
    final mentionQuery = isGroup ? _activeMentionQuery() : null;
    final mentionCandidates = mentionQuery == null
        ? const <MapEntry<String, String>>[]
        : participantNames.entries
            .where(
              (entry) =>
                  entry.key != myUid &&
                  entry.value.toLowerCase().contains(mentionQuery.toLowerCase()),
            )
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: isGroup
              ? () => context.push('/group/${widget.conversationId}/info')
              : null,
          child: Row(
            children: [
              UserAvatar(
                photoUrl: isGroup ? conversation?.groupAvatarUrl : otherProfile?.photoUrl,
                displayName: headerTitle,
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
                          child: Text(headerTitle, overflow: TextOverflow.ellipsis),
                        ),
                        if (isE2eeEnabled) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.lock, size: 14, color: Theme.of(context).colorScheme.primary),
                        ],
                        if (!isGroup &&
                            otherUsername != null &&
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
                    if (typingLabel != null)
                      Text(
                        typingLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontStyle: FontStyle.italic,
                            ),
                      )
                    else if (isGroup)
                      Text(
                        '${conversation?.participants.length ?? 0} members',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else if (isE2eeEnabled)
                      Text(
                        '🔒 Encrypted',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      )
                    else if (presence != null)
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
        actions: [
          PopupMenuButton<void>(
            itemBuilder: (_) => [
              if (isGroup)
                PopupMenuItem<void>(
                  onTap: () => Future(() {
                    if (context.mounted) {
                      context.push('/group/${widget.conversationId}/info');
                    }
                  }),
                  child: const Text('Group info'),
                ),
              if (!isGroup)
                PopupMenuItem<void>(
                  onTap: () => Future(() {
                    if (context.mounted) _toggleE2ee(context, isE2eeEnabled);
                  }),
                  child: Text(isE2eeEnabled ? 'Disable encryption' : 'Enable encryption'),
                ),
              PopupMenuItem<void>(
                // Deferred to a microtask so the popup route finishes
                // closing before the dialog opens; uses the State's own
                // (stable, long-lived) context rather than itemBuilder's
                // transient one, which the popup route owns and tears
                // down as part of closing.
                onTap: () => Future(() {
                  if (context.mounted) _confirmClearChat(context);
                }),
                child: const Text('Clear chat'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Something went wrong: $error')),
              data: (messages) {
                // "Delete for me" hides a message only from the deleter's
                // own view — the doc and its content stay untouched for
                // the other participant, so this filter (not a rules
                // change) is what actually implements it. clearedAt does
                // the same for "Clear chat"/"Delete chat" in bulk: hide
                // everything at-or-before whenever this user last cleared
                // this conversation.
                final clearedAt = conversation?.clearedFor[myUid];
                final visibleMessages = messages
                    .where(
                      (m) =>
                          m.deletedFor[myUid] != true &&
                          (clearedAt == null ||
                              m.timestamp == null ||
                              m.timestamp!.isAfter(clearedAt)),
                    )
                    .toList();
                if (visibleMessages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Say hello.'),
                  );
                }
                if (myUid != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref
                        .read(chatRepositoryProvider)
                        .markMessagesRead(
                          conversationId: widget.conversationId,
                          myUid: myUid,
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
                    itemCount: visibleMessages.length,
                    itemBuilder: (context, index) {
                      final message = visibleMessages[index];
                      return MessageBubble(
                        key: _keyFor(message.id),
                        message: message,
                        isMine: message.senderId == myUid,
                        isGroup: isGroup,
                        conversationId: widget.conversationId,
                        recipientIds: recipientIds,
                        currentUserId: myUid ?? '',
                        participantNames: participantNames,
                        onReplyTap: (id) =>
                            _scrollToMessage(id, visibleMessages),
                        onEdit: _startEditing,
                        isHighlighted: message.id == _highlightedMessageId,
                        myLanguageCode: myLanguageCode,
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
                  if (_editingMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ReplyPreviewStrip(
                        senderLabel: 'Editing message',
                        preview: _editingMessage!.text,
                        onCancel: _cancelEditing,
                      ),
                    )
                  else if (replyingTo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ReplyPreviewStrip(
                        senderLabel: nameFor(replyingTo.senderId),
                        preview: ReplyPreview.fromMessage(
                          replyingTo,
                        ).previewLabel,
                        onCancel: () =>
                            ref.read(replyingToProvider.notifier).clear(),
                      ),
                    ),
                  if (mentionCandidates.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: mentionCandidates.length,
                        itemBuilder: (context, index) {
                          final candidate = mentionCandidates[index];
                          return ListTile(
                            dense: true,
                            leading: UserAvatar(photoUrl: null, displayName: candidate.value, radius: 14),
                            title: Text(candidate.value),
                            onTap: () => _selectMention(candidate.key, candidate.value),
                          );
                        },
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
                          onPressed: recipientIds.isEmpty
                              ? null
                              : () => _sendImage(recipientIds),
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
                              onChanged: _onMessageTextChanged,
                              onSubmitted: (_) => _send(recipientIds),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _textController,
                          builder: (context, value, _) {
                            if (value.text.trim().isEmpty &&
                                _editingMessage == null) {
                              return IconButton.filled(
                                icon: const Icon(Icons.mic),
                                onPressed: recipientIds.isEmpty
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
                                  : () => _send(recipientIds),
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

  Future<void> _send(List<String> recipientIds) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _stopTyping();

    final conversation = ref.read(conversationDetailProvider(widget.conversationId)).value;
    final isE2eeEnabled = conversation != null && !conversation.isGroup && conversation.e2eeEnabled;
    final otherUid = recipientIds.isNotEmpty ? recipientIds.first : null;

    final editing = _editingMessage;
    if (editing != null) {
      var newText = text;
      if (editing.encrypted && otherUid != null) {
        try {
          newText = await ref.read(e2eeRepositoryProvider).encryptFor(otherUid, text);
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Could not encrypt edit: $error')));
          }
          return;
        }
      }
      _textController.clear();
      setState(() => _editingMessage = null);
      await ref
          .read(chatRepositoryProvider)
          .editMessage(
            conversationId: widget.conversationId,
            messageId: editing.id,
            newText: newText,
          );
      return;
    }

    if (recipientIds.isEmpty) return;
    final replyingTo = ref.read(replyingToProvider);
    // Only keep mentions whose "@Name" text is still actually present —
    // guards against a stale entry if the user inserted one and then
    // deleted or edited it away before hitting send.
    final mentions = _draftMentions.entries
        .where((entry) => text.contains('@${entry.value}'))
        .map((entry) => entry.key)
        .toList();

    var outgoingText = text;
    if (isE2eeEnabled && otherUid != null) {
      try {
        outgoingText = await ref.read(e2eeRepositoryProvider).encryptFor(otherUid, text);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Could not send encrypted message: $error')));
        }
        return;
      }
    }

    _draftMentions.clear();
    _textController.clear();
    ref.read(replyingToProvider.notifier).clear();
    await ref
        .read(sendMessageControllerProvider.notifier)
        .send(
          conversationId: widget.conversationId,
          recipientIds: recipientIds,
          text: outgoingText,
          replyTo: replyingTo == null
              ? null
              : ReplyPreview.fromMessage(replyingTo),
          mentions: mentions,
          encrypted: isE2eeEnabled,
        );
  }

  void _startEditing(Message message) {
    ref.read(replyingToProvider.notifier).clear();
    _textController.text = message.text;
    _textController.selection = TextSelection.collapsed(
      offset: message.text.length,
    );
    setState(() => _editingMessage = message);
  }

  void _cancelEditing() {
    _textController.clear();
    setState(() => _editingMessage = null);
  }

  Future<void> _confirmClearChat(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text(
          'This clears the chat history from your view only — the other '
          'person keeps seeing their messages normally.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(conversationRepositoryProvider)
          .clearChatForMe(widget.conversationId);
    }
  }

  /// Basic E2EE MVP toggle — turning it on doesn't itself require the
  /// other person's key to already exist (their device publishes one the
  /// next time they're signed in, via e2eeKeyTrackerProvider); the actual
  /// encrypt call in _send surfaces a clear error if it's still missing
  /// when a message is genuinely sent.
  Future<void> _toggleE2ee(BuildContext context, bool currentlyEnabled) async {
    if (!currentlyEnabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enable encryption?'),
          content: const Text(
            'New messages you send from here on will be end-to-end '
            'encrypted (text only). This is a basic demonstration, not a '
            'full production-grade protocol — translation and rich push '
            'previews are unavailable for encrypted messages. Existing '
            'messages in this chat are not affected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Enable'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await ref
        .read(conversationRepositoryProvider)
        .setE2eeEnabled(widget.conversationId, !currentlyEnabled);
  }

  Future<void> _sendImage(List<String> recipientIds) async {
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
          recipientIds: recipientIds,
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
    final myUid = ref.read(authStateChangesProvider).value?.uid;
    final conversation = ref
        .read(conversationDetailProvider(widget.conversationId))
        .value;
    final recipientIds = (myUid != null && conversation != null)
        ? conversation.otherParticipantIds(myUid)
        : const <String>[];
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    final duration = _recordSeconds;
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordingPath = null;
    });

    final resolvedPath = path ?? _recordingPath;
    if (resolvedPath == null || recipientIds.isEmpty || duration < 1) return;

    final replyingTo = ref.read(replyingToProvider);
    ref.read(replyingToProvider.notifier).clear();
    await ref
        .read(sendVoiceMessageControllerProvider.notifier)
        .send(
          conversationId: widget.conversationId,
          recipientIds: recipientIds,
          file: File(resolvedPath),
          durationSeconds: duration,
          replyTo: replyingTo == null
              ? null
              : ReplyPreview.fromMessage(replyingTo),
        );
  }
}
