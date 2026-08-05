class PresenceStatus {
  const PresenceStatus({required this.isOnline, this.lastSeen});

  final bool isOnline;
  final DateTime? lastSeen;

  static const offline = PresenceStatus(isOnline: false, lastSeen: null);
}
