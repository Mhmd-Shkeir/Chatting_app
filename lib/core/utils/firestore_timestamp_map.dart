import 'package:cloud_firestore/cloud_firestore.dart';

/// Parses a Firestore map field (uid -> Timestamp, e.g. `clearedFor` or
/// `readBy`) into uid -> DateTime, silently skipping any entry whose value
/// isn't a Timestamp yet.
///
/// A map entry written with `FieldValue.serverTimestamp()` reads back as
/// `null` in the local cache until the server acknowledges that specific
/// write — normal any time the write is still offline/pending, not just a
/// rare race (e.g. clearing a group chat while offline never syncs until
/// connectivity returns). A plain `as Timestamp` cast on that value
/// crashes with "type 'null' is not a subtype of type 'Timestamp'".
/// Skipping the entry here instead just treats that uid as "not set yet"
/// until the real write syncs and the listener fires again with the
/// resolved value — no data loss, no crash.
Map<String, DateTime> timestampMapFrom(dynamic raw) {
  if (raw is! Map) return const {};
  final result = <String, DateTime>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is Timestamp) {
      result[entry.key as String] = value.toDate();
    }
  }
  return result;
}
