import '../data/database.dart';
import 'dates.dart';

/// Data for the "Today" home-screen widget.
///
/// The widget runs without the app, so it gets a snapshot for today and tomorrow (keyed by
/// day) plus the next few events with their times. At midnight it switches to tomorrow's
/// snapshot on its own, and it picks the next event that has not ended yet, so it stays right
/// even if Plania is not opened. While the app lock is on, titles are left out: only counts
/// and times are shown on the home screen.
Map<String, Object?> todayWidgetData({
  required List<TaskRow> tasks,
  required List<HabitRow> habits,
  required Map<String, Set<String>> habitDays,
  required List<CalendarEventRow> events,
  required DateTime now,
  required bool locked,
}) {
  final today = dateOnly(now);
  final active = habits.where((h) => h.isActive).toList();

  Map<String, Object?> day(DateTime d) {
    // Same rule as Home's "Due today": open top-level tasks due on this day or earlier.
    final due = tasks
        .where((t) => t.parentId == null && !t.isCompleted && t.dueDate != null && daysBetween(d, t.dueDate!) <= 0)
        .toList()
      ..sort((a, b) {
        final c = b.priority.compareTo(a.priority);
        return c != 0 ? c : a.dueDate!.compareTo(b.dueDate!);
      });
    final key = dayKey(d);
    return {
      'tasks': due.length,
      'titles': locked ? const <String>[] : [for (final t in due.take(3)) t.title],
      'habitsDone': active.where((h) => habitDays[h.id]?.contains(key) ?? false).length,
    };
  }

  final upcoming = events.where((e) => e.endTime.isAfter(now)).toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
  final tomorrow = addDays(today, 1);
  return {
    'v': 1,
    'locked': locked,
    'habitsTotal': active.length,
    'days': {dayKey(today): day(today), dayKey(tomorrow): day(tomorrow)},
    'events': [
      for (final e in upcoming.take(8))
        {
          'title': locked ? '' : e.title,
          'start': e.startTime.millisecondsSinceEpoch,
          'end': e.endTime.millisecondsSinceEpoch,
          'allDay': e.isAllDay,
        },
    ],
  };
}
