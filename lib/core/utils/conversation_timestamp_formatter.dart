import 'package:intl/intl.dart';

String formatConversationTimestamp(DateTime? timestamp) {
  if (timestamp == null) return '';

  final now = DateTime.now();
  final isToday =
      timestamp.year == now.year && timestamp.month == now.month && timestamp.day == now.day;
  if (isToday) return DateFormat.jm().format(timestamp);

  final isThisWeek = now.difference(timestamp).inDays < 7;
  if (isThisWeek) return DateFormat.E().format(timestamp);

  return DateFormat.yMd().format(timestamp);
}
