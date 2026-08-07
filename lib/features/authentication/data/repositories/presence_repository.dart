import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/presence_status.dart';

class PresenceRepository {
  PresenceRepository({FirebaseDatabase? database, FirebaseAuth? auth})
      : _database = database ?? FirebaseDatabase.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseDatabase _database;
  final FirebaseAuth _auth;

  StreamSubscription<DatabaseEvent>? _connectionSubscription;
  String? _trackedUid;

  /// Marks the current user online for as long as the socket to Realtime
  /// Database stays connected, and registers an onDisconnect write so the
  /// server flips them back to offline the moment the connection drops
  /// (app killed, network lost) without the client having to do anything.
  void startTracking() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _connectionSubscription != null) return;

    _trackedUid = uid;
    final presenceRef = _database.ref('presence/$uid');
    final connectedRef = _database.ref('.info/connected');

    _connectionSubscription = connectedRef.onValue.listen((event) async {
      final connected = event.snapshot.value as bool? ?? false;
      if (!connected) return;

      await presenceRef.onDisconnect().set({
        'isOnline': false,
        'lastSeen': ServerValue.timestamp,
      });

      await presenceRef.set({
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
      });
    });
  }

  /// For an explicit logout, where the app keeps running and the socket
  /// stays open, so onDisconnect alone wouldn't fire.
  Future<void> stopTracking() async {
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    final uid = _trackedUid;
    _trackedUid = null;
    if (uid == null) return;

    await _database.ref('presence/$uid').set({
      'isOnline': false,
      'lastSeen': ServerValue.timestamp,
    });
  }

  /// For account deletion — removes the node entirely rather than just
  /// marking offline, so no stale presence data lingers for an account
  /// that no longer exists.
  Future<void> deletePresence(String uid) => _database.ref('presence/$uid').remove();

  Stream<PresenceStatus> watchPresence(String uid) {
    return _database.ref('presence/$uid').onValue.map((event) {
      final data = event.snapshot.value;
      if (data is! Map) return PresenceStatus.offline;

      final lastSeenMillis = data['lastSeen'] as int?;
      return PresenceStatus(
        isOnline: data['isOnline'] as bool? ?? false,
        lastSeen: lastSeenMillis != null
            ? DateTime.fromMillisecondsSinceEpoch(lastSeenMillis)
            : null,
      );
    });
  }
}
