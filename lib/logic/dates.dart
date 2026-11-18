import 'package:intl/intl.dart';

/// Local calendar-day helpers. Day arithmetic goes through the DateTime constructor
/// (not Duration) so daylight-saving changes never skip or repeat a day.

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days, d.hour, d.minute);

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// `yyyy-MM-dd` key for a local day.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseDayKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// A task due date without a time is stored at local midnight.
bool hasTime(DateTime d) => d.hour != 0 || d.minute != 0;

/// Whole days from [from] to [to] (calendar days, ignores time of day).
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

String fmtTime(DateTime d) => DateFormat.jm().format(d);

String fmtDate(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  return d.year == n.year ? DateFormat('EEE, MMM d').format(d) : DateFormat('MMM d, y').format(d);
}

/// "Today", "Tomorrow", "Yesterday", or a short date.
String relativeDay(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = daysBetween(n, d);
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return fmtDate(d, now: n);
}

/// "Today 3:00 PM" / "Tomorrow" / "Mon, Nov 17 9:30 AM".
String fmtDue(DateTime d, {DateTime? now}) {
  final day = relativeDay(d, now: now);
  return hasTime(d) ? '$day ${fmtTime(d)}' : day;
}

DateTime monthStart(DateTime d) => DateTime(d.year, d.month);

DateTime addMonths(DateTime d, int months) => DateTime(d.year, d.month + months);
