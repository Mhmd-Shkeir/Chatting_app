enum AssistantRole { user, assistant }

/// A single turn in an AI Assistant conversation. In-memory only for this
/// session — the Assistant has no Firestore-backed history, unlike regular
/// chats, since nothing in the spec calls for persisting or syncing it
/// across devices.
class AssistantMessage {
  const AssistantMessage({
    required this.role,
    required this.text,
    this.failed = false,
  });

  final AssistantRole role;
  final String text;

  /// Set on the placeholder reply shown when the request to the Worker
  /// fails (network error, non-200, etc.) — lets the bubble render
  /// differently (e.g. an error tint) without a separate message type.
  final bool failed;
}
