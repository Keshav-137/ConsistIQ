import 'package:intl/intl.dart';

String dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

DateTime parseKey(String k) {
  final p = k.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

String fmtHm(int h, int m) => DateFormat('h:mm a').format(DateTime(2000, 1, 1, h, m));
String fmtDate(DateTime d) => DateFormat('EEE, d MMM').format(d);
String fmtDateTime(DateTime d) => DateFormat('d MMM, h:mm a').format(d);

String fmtDuration(Duration d) {
  if (d.isNegative) return '0s';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m ${s}s';
}

/// Key of one occurrence: task + day + time-slot index.
String occKey(String id, String dk, int slot) => '$id|$dk|$slot';
