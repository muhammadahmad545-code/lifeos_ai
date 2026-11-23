import 'dart:convert';

import 'dates.dart';

// Pure helpers shared by the repository, the screens and the assistant. No Flutter imports,
// so everything here is unit-tested directly.

// ---------------------------------------------------------------------------
// Tasks
// ---------------------------------------------------------------------------

const List<String> kPriorityLabels = ['Low', 'Medium', 'High', 'Urgent'];

String priorityLabel(int p) => kPriorityLabels[p.clamp(0, kPriorityLabels.length - 1)];

/// Stored recurrence values ('none', 'daily', 'weekly', 'monthly' come from 1.x).
const List<String> kRecurrences = ['none', 'daily', 'weekdays', 'weekly', 'monthly', 'yearly'];

String recurrenceLabel(String r) => switch (r) {
      'daily' => 'Daily',
      'weekdays' => 'Weekdays',
      'weekly' => 'Weekly',
      'monthly' => 'Monthly',
      'yearly' => 'Yearly',
      _ => 'Never',
    };

/// [base] plus [months], clamped to the end of short months (Jan 31 -> Feb 28/29).
DateTime addMonthsClamped(DateTime base, int months) {
  final first = DateTime(base.year, base.month + months);
  final lastDay = DateTime(first.year, first.month + 1, 0).day;
  final day = base.day > lastDay ? lastDay : base.day;
  return DateTime(first.year, first.month, day, base.hour, base.minute);
}

/// Next due date for a repeating task. Monthly/yearly clamp to the end of short months
/// (Jan 31 -> Feb 28/29).
DateTime nextDue(DateTime base, String recurrence) {
  switch (recurrence) {
    case 'daily':
      return addDays(base, 1);
    case 'weekdays':
      var d = addDays(base, 1);
      while (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
        d = addDays(d, 1);
      }
      return d;
    case 'weekly':
      return addDays(base, 7);
    case 'monthly':
      return addMonthsClamped(base, 1);
    case 'yearly':
      return addMonthsClamped(base, 12);
    default:
      return base;
  }
}

enum DueBucket { overdue, today, upcoming, someday }

DueBucket dueBucket(DateTime? due, DateTime now) {
  if (due == null) return DueBucket.someday;
  final diff = daysBetween(now, due);
  if (diff < 0) return DueBucket.overdue;
  if (diff == 0) return DueBucket.today;
  return DueBucket.upcoming;
}

// ---------------------------------------------------------------------------
// Habits
// ---------------------------------------------------------------------------

/// Consecutive days ending today. If today is not done yet, the streak ending yesterday
/// still counts (it is not broken until the day is over).
int currentStreak(Set<String> days, DateTime today) {
  var d = dateOnly(today);
  if (!days.contains(dayKey(d))) d = addDays(d, -1);
  var n = 0;
  while (days.contains(dayKey(d))) {
    n++;
    d = addDays(d, -1);
  }
  return n;
}

int bestStreak(Set<String> days) {
  final sorted = days.map(parseDayKey).whereType<DateTime>().toList()..sort();
  var best = 0;
  var run = 0;
  DateTime? prev;
  for (final d in sorted) {
    run = (prev != null && daysBetween(prev, d) == 1) ? run + 1 : 1;
    if (run > best) best = run;
    prev = d;
  }
  return best;
}

// ---------------------------------------------------------------------------
// Checklists (notes) and milestones (goals)
// ---------------------------------------------------------------------------

class CheckItem {
  const CheckItem(this.text, {this.done = false});

  final String text;
  final bool done;

  CheckItem copyWith({String? text, bool? done}) => CheckItem(text ?? this.text, done: done ?? this.done);

  @override
  bool operator ==(Object other) => other is CheckItem && other.text == text && other.done == done;

  @override
  int get hashCode => Object.hash(text, done);
}

List<CheckItem> decodeChecklist(String raw) {
  if (raw.trim().isEmpty) return const [];
  try {
    final list = jsonDecode(raw);
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map) CheckItem('${e['t'] ?? ''}', done: e['d'] == true),
    ];
  } catch (_) {
    return const [];
  }
}

String encodeChecklist(List<CheckItem> items) {
  final kept = items.where((i) => i.text.trim().isNotEmpty).toList();
  if (kept.isEmpty) return '';
  return jsonEncode([
    for (final i in kept) {'t': i.text.trim(), 'd': i.done},
  ]);
}

/// Goal milestones are stored '|'-separated (1.x format); done ones start with "[x] ".
List<CheckItem> decodeMilestones(String raw) {
  if (raw.trim().isEmpty) return const [];
  return [
    for (final part in raw.split('|'))
      if (part.trim().isNotEmpty)
        part.trim().startsWith('[x] ')
            ? CheckItem(part.trim().substring(4).trim(), done: true)
            : CheckItem(part.trim()),
  ];
}

String encodeMilestones(List<CheckItem> items) => items
    .where((i) => i.text.trim().isNotEmpty)
    .map((i) => '${i.done ? '[x] ' : ''}${i.text.trim().replaceAll('|', '/')}')
    .join('|');

/// Goal progress (0..1): milestone share when there are milestones, otherwise the manual value.
double goalProgress({required String milestones, required double manual, required bool completed}) {
  if (completed) return 1;
  final items = decodeMilestones(milestones);
  if (items.isEmpty) return manual.clamp(0.0, 1.0);
  return items.where((i) => i.done).length / items.length;
}

// ---------------------------------------------------------------------------
// Money
// ---------------------------------------------------------------------------

const List<String> kExpenseCategories = [
  'Food',
  'Groceries',
  'Transport',
  'Shopping',
  'Bills',
  'Health',
  'Entertainment',
  'Education',
  'Other',
];

const List<String> kIncomeCategories = ['Salary', 'Freelance', 'Gift', 'Other'];

/// Parses a user-typed amount ("1,250.50", " 12 "). Returns null for invalid or non-positive values.
double? parseAmount(String input) {
  final cleaned = input.trim().replaceAll(',', '').replaceAll(' ', '');
  final v = double.tryParse(cleaned);
  if (v == null || v.isNaN || v.isInfinite || v <= 0) return null;
  return (v * 100).roundToDouble() / 100;
}

// ---------------------------------------------------------------------------
// Recurring expenses and income
// ---------------------------------------------------------------------------

/// How often a recurring entry repeats.
const List<String> kRecurringFrequencies = ['weekly', 'monthly'];

String frequencyLabel(String f) => f == 'weekly' ? 'Weekly' : 'Monthly';

/// The date of occurrence [index] (0 = the start date). Monthly entries keep their day of the
/// month and clamp to the end of short months, so the 31st becomes Feb 28 and then Mar 31 again.
DateTime recurringOccurrence(DateTime start, String frequency, int index) =>
    frequency == 'weekly' ? addDays(start, 7 * index) : addMonthsClamped(start, index);

/// Indexes from [nextIndex] whose day has come (on or before [now]'s day). Capped so a broken
/// start date can never post thousands of entries.
List<int> dueOccurrences(DateTime start, String frequency, int nextIndex, DateTime now, {int cap = 400}) {
  final today = dateOnly(now);
  final out = <int>[];
  for (var i = nextIndex < 0 ? 0 : nextIndex; out.length < cap; i++) {
    if (dateOnly(recurringOccurrence(start, frequency, i)).isAfter(today)) break;
    out.add(i);
  }
  return out;
}

/// The first index from [from] whose day is today or later (used when resuming a paused entry,
/// so the occurrences missed while paused are skipped instead of posted).
int firstOccurrenceFrom(DateTime start, String frequency, int from, DateTime now) {
  final today = dateOnly(now);
  var i = from < 0 ? 0 : from;
  while (dateOnly(recurringOccurrence(start, frequency, i)).isBefore(today) && i < from + 10000) {
    i++;
  }
  return i;
}

/// "Monthly on the 5th" / "Weekly on Monday".
String recurringScheduleLabel(DateTime start, String frequency) {
  if (frequency == 'weekly') {
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return 'Weekly on ${names[start.weekday - 1]}';
  }
  final d = start.day;
  final suffix = (d % 100 >= 11 && d % 100 <= 13) ? 'th' : switch (d % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' };
  return d >= 29 ? 'Monthly on the $d$suffix (or the last day)' : 'Monthly on the $d$suffix';
}
