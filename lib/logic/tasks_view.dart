import '../data/database.dart';
import 'dates.dart';
import 'rules.dart';

// Pure helpers for the Tasks tab and Task insights.

/// Open top-level tasks per category, every category present (zero when empty).
Map<String, int> openCountsByCategory(Iterable<TaskRow> tasks) {
  final counts = {for (final c in kTaskCategories) c: 0};
  for (final t in tasks) {
    if (t.parentId != null || t.isCompleted) continue;
    final c = taskCategory(t.project);
    counts[c] = counts[c]! + 1;
  }
  return counts;
}

/// Top-level tasks in [category] (all when null) whose title or notes contain [query].
List<TaskRow> filterTasks(Iterable<TaskRow> tasks, {String? category, String query = ''}) {
  final q = query.trim().toLowerCase();
  return [
    for (final t in tasks)
      if (t.parentId == null &&
          (category == null || taskCategory(t.project) == category) &&
          (q.isEmpty || t.title.toLowerCase().contains(q) || (t.description?.toLowerCase().contains(q) ?? false)))
        t,
  ];
}

class TaskInsights {
  const TaskInsights({
    required this.completedToday,
    required this.streak,
    required this.weekDone,
    required this.weekOpen,
    required this.overdue,
    required this.last7,
    required this.last7Labels,
    required this.openByCategory,
  });

  final int completedToday;

  /// Consecutive days, ending today (or yesterday if nothing is done yet today), with at least
  /// one completion.
  final int streak;

  /// Completed this week (Monday to Sunday) and still open with a due date this week.
  final int weekDone;
  final int weekOpen;
  final int overdue;

  /// Completions per day for the last seven days, oldest first (today last).
  final List<int> last7;
  final List<String> last7Labels;
  final Map<String, int> openByCategory;

  /// Share of this week's tasks that are done, or null when there were none.
  double? get weekRate => weekDone + weekOpen == 0 ? null : weekDone / (weekDone + weekOpen);
}

DateTime weekStart(DateTime d) => addDays(dateOnly(d), -(d.weekday - DateTime.monday));

TaskInsights computeInsights(List<TaskRow> tasks, List<TaskCompletionRow> completions, DateTime now) {
  final today = dateOnly(now);
  final days = {for (final c in completions) dayKey(c.completedAt)};
  final perDay = <String, int>{};
  for (final c in completions) {
    final k = dayKey(c.completedAt);
    perDay[k] = (perDay[k] ?? 0) + 1;
  }
  final start = weekStart(now);
  final end = addDays(start, 7);
  bool inWeek(DateTime d) => !d.isBefore(start) && d.isBefore(end);

  final open = tasks.where((t) => t.parentId == null && !t.isCompleted).toList();
  const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  final last7Days = [for (var i = 6; i >= 0; i--) addDays(today, -i)];
  return TaskInsights(
    completedToday: perDay[dayKey(today)] ?? 0,
    streak: currentStreak(days, now),
    weekDone: completions.where((c) => inWeek(c.completedAt)).length,
    weekOpen: open.where((t) => t.dueDate != null && inWeek(t.dueDate!)).length,
    overdue: open.where((t) => dueBucket(t.dueDate, now) == DueBucket.overdue).length,
    last7: [for (final d in last7Days) perDay[dayKey(d)] ?? 0],
    last7Labels: [for (final d in last7Days) weekdays[d.weekday - 1]],
    openByCategory: openCountsByCategory(tasks),
  );
}
