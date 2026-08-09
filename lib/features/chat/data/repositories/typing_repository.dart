import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// Same Realtime Database + onDisconnect pattern as PresenceRepository —
/// typing state is transient, so RTDB (not Firestore) is the right fit,
/// and onDisconnect gives the same free cleanup on a killed app/dropped
/// connection that presence relies on, without a client having to do
/// anything.
class TypingRepository {
  TypingRepository({FirebaseDatabase? database, FirebaseAuth? auth})
      : _database = database ?? FirebaseDatabase.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseDatabase _database;
  final FirebaseAuth _auth;

  /// Sets or clears the caller's own typing flag for [conversationId]. The
  /// "on" write stores a server timestamp rather than a bare `true` — the
  /// primary way it turns back off is still the compose bar's idle timer
  /// calling this with isTyping: false (an explicit remove, fast), but
  /// storing a timestamp lets readers self-heal (see watchTypingTimestamps)
  /// if that explicit clear is ever lost — an out-of-order write landing
  /// after it, the app being killed before onDisconnect's remove can fire,
  /// etc. — instead of an indicator that can get stuck on forever.
  Future<void> setTyping({required String conversationId, required bool isTyping}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final ref = _database.ref('typing/$conversationId/$uid');
    if (isTyping) {
      await ref.onDisconnect().remove();
      await ref.set(ServerValue.timestamp);
    } else {
      await ref.onDisconnect().cancel();
      await ref.remove();
    }
  }

  /// Uid -> when they last signaled typing (server millis since epoch) for
  /// [conversationId] — includes the caller's own uid, which callers filter
  /// out (see typingUidsProvider). Callers are responsible for treating an
  /// old-enough timestamp as no longer typing (see ChatScreen), since this
  /// stream only emits on a data change, not merely because time passed.
  Stream<Map<String, int>> watchTypingTimestamps(String conversationId) {
    return _database.ref('typing/$conversationId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data is! Map) return const <String, int>{};
      return data.map((key, value) => MapEntry(key as String, value as int));
    });
  }
}
