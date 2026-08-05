String formatLastSeen(DateTime? lastSeen) {
  if (lastSeen == null) return 'Offline';

  final diff = DateTime.now().difference(lastSeen);
  if (diff.inMinutes < 1) return 'Last seen just now';
  if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';
  if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
  if (diff.inDays < 7) return 'Last seen ${diff.inDays}d ago';
  return 'Last seen recently';
}
