import '../data/database.dart';
import 'dates.dart';
import 'rules.dart';

/// Everything the assistant may look at. It never leaves the device.
class AssistantData {
  const AssistantData({
    this.tasks = const [],
    this.events = const [],
    this.habits = const [],
    this.habitDays = const {},
    this.expenses = const [],
    this.budgets = const [],
    this.goals = const [],
    this.focus = const [],
    this.journal = const [],
    this.notes = const [],
  });

  final List<TaskRow> tasks;
  final List<CalendarEventRow> events;
  final List<HabitRow> habits;
  final Map<String, Set<String>> habitDays;
  final List<ExpenseRow> expenses;
  final List<BudgetRow> budgets;
  final List<GoalRow> goals;
  final List<FocusSessionRow> focus;
  final List<JournalEntryRow> journal;
  final List<NoteRow> notes;
}

enum AssistantTopic { today, overdue, week, spending, habits, goals, focus, journal, notes, help }

/// Suggested questions shown as chips.
const Map<AssistantTopic, String> kAssistantPrompts = {
  AssistantTopic.today: 'Plan my day',
  AssistantTopic.overdue: "What's overdue?",
  AssistantTopic.week: 'My week ahead',
  AssistantTopic.spending: 'Spending this month',
  AssistantTopic.habits: 'Habit streaks',
  AssistantTopic.goals: 'Goal progress',
  AssistantTopic.focus: 'Focus time',
  AssistantTopic.journal: 'Mood lately',
};

/// A rule-based helper that answers questions about the user's own data. It matches
/// keywords to a topic and builds the answer from the data; nothing is generated or sent anywhere.
class Assistant {
  const Assistant(this.data, {required this.money, required this.now});

  final AssistantData data;
  final String Function(double) money;
  final DateTime now;

  static AssistantTopic topicFor(String question) {
    final q = question.toLowerCase();
    // Words match at the start of a word, so "late" does not match "translate".
    bool has(List<String> words) => words.any((w) => RegExp('\\b${RegExp.escape(w)}').hasMatch(q));
    if (has(['overdue', 'late', 'behind', 'missed'])) return AssistantTopic.overdue;
    if (has(['spend', 'spent', 'expense', 'money', 'budget', 'income', 'cost', 'paid', 'finance'])) {
      return AssistantTopic.spending;
    }
    if (has(['habit', 'streak', 'routine'])) return AssistantTopic.habits;
    if (has(['goal', 'milestone', 'target'])) return AssistantTopic.goals;
    if (has(['focus', 'pomodoro', 'deep work', 'concentrat'])) return AssistantTopic.focus;
    if (has(['mood', 'journal', 'feel', 'diary'])) return AssistantTopic.journal;
    if (has(['note'])) return AssistantTopic.notes;
    if (has(['week', 'upcoming', 'tomorrow', 'next few', 'coming up'])) return AssistantTopic.week;
    if (has(['today', 'plan', 'day', 'agenda', 'schedule', 'what should', 'first', 'priorit', 'task', 'todo', 'to do'])) {
      return AssistantTopic.today;
    }
    return AssistantTopic.help;
  }

  String answer(String question) => answerTopic(topicFor(question));

  String answerTopic(AssistantTopic topic) => switch (topic) {
        AssistantTopic.today => _today(),
        AssistantTopic.overdue => _overdue(),
        AssistantTopic.week => _week(),
        AssistantTopic.spending => _spending(),
        AssistantTopic.habits => _habits(),
        AssistantTopic.goals => _goals(),
        AssistantTopic.focus => _focus(),
        AssistantTopic.journal => _journal(),
        AssistantTopic.notes => _notes(),
        AssistantTopic.help => _help(),
      };

  List<TaskRow> get _open => data.tasks.where((t) => !t.isCompleted && t.parentId == null).toList();

  int _byUrgency(TaskRow a, TaskRow b) {
    final p = b.priority.compareTo(a.priority);
    if (p != 0) return p;
    final ad = a.dueDate, bd = b.dueDate;
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  }

  String _taskLine(TaskRow t) {
    final bits = <String>[];
    if (t.priority >= 2) bits.add(priorityLabel(t.priority).toLowerCase());
    if (t.dueDate != null && hasTime(t.dueDate!)) bits.add(fmtTime(t.dueDate!));
    return '• ${t.title}${bits.isEmpty ? '' : ' (${bits.join(', ')})'}';
  }

  List<CalendarEventRow> _eventsOn(DateTime day) {
    final start = dateOnly(day);
    final end = addDays(start, 1);
    return data.events.where((e) => e.startTime.isBefore(end) && !e.endTime.isBefore(start)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  String _today() {
    final open = _open;
    final overdue = open.where((t) => dueBucket(t.dueDate, now) == DueBucket.overdue).toList()..sort(_byUrgency);
    final today = open.where((t) => dueBucket(t.dueDate, now) == DueBucket.today).toList()..sort(_byUrgency);
    final events = _eventsOn(now);
    final todayKey = dayKey(now);
    final habitsLeft = data.habits.where((h) => h.isActive && !(data.habitDays[h.id]?.contains(todayKey) ?? false)).toList();

    if (overdue.isEmpty && today.isEmpty && events.isEmpty && habitsLeft.isEmpty) {
      final next = open.where((t) => t.dueDate != null).toList()..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
      return 'Your day is clear: nothing due, no events and no habits left.'
          '${next.isEmpty ? '' : '\n\nNext up: ${next.first.title} (${fmtDue(next.first.dueDate!, now: now)}).'}';
    }

    final out = StringBuffer('Here is your plan for ${fmtDate(now, now: now)}.');
    final first = overdue.isNotEmpty ? overdue.first : (today.isNotEmpty ? today.first : null);
    if (first != null) out.write('\n\nStart with: ${first.title}.');
    if (events.isNotEmpty) {
      out.write('\n\nSchedule');
      for (final e in events) {
        out.write('\n• ${e.isAllDay ? 'All day' : fmtTime(e.startTime)}  ${e.title}');
      }
    }
    if (overdue.isNotEmpty) {
      out.write('\n\nOverdue (${overdue.length})');
      for (final t in overdue.take(5)) {
        out.write('\n${_taskLine(t)}');
      }
    }
    if (today.isNotEmpty) {
      out.write('\n\nDue today (${today.length})');
      for (final t in today.take(8)) {
        out.write('\n${_taskLine(t)}');
      }
    }
    if (habitsLeft.isNotEmpty) {
      out.write('\n\nHabits still to do: ${habitsLeft.map((h) => h.name).join(', ')}.');
    }
    final focusToday = _focusMinutes(dateOnly(now), addDays(dateOnly(now), 1));
    if (focusToday > 0) out.write('\n\nYou have focused for $focusToday min today.');
    return out.toString();
  }

  String _overdue() {
    final overdue = _open.where((t) => dueBucket(t.dueDate, now) == DueBucket.overdue).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    if (overdue.isEmpty) return 'Nothing is overdue. Nice work.';
    final out = StringBuffer('${overdue.length} overdue ${overdue.length == 1 ? 'task' : 'tasks'}:');
    for (final t in overdue.take(10)) {
      final late = daysBetween(t.dueDate!, now);
      out.write('\n• ${t.title}: $late ${late == 1 ? 'day' : 'days'} late');
    }
    if (overdue.length > 10) out.write('\n…and ${overdue.length - 10} more.');
    out.write('\n\nTip: reschedule what you will not do this week, so today stays realistic.');
    return out.toString();
  }

  String _week() {
    final start = dateOnly(now);
    final out = StringBuffer('The next 7 days:');
    var any = false;
    for (var i = 0; i < 7; i++) {
      final day = addDays(start, i);
      final tasks = _open.where((t) => t.dueDate != null && sameDay(t.dueDate!, day)).toList()..sort(_byUrgency);
      final events = _eventsOn(day);
      if (tasks.isEmpty && events.isEmpty) continue;
      any = true;
      out.write('\n\n${relativeDay(day, now: now)}');
      for (final e in events) {
        out.write('\n• ${e.isAllDay ? 'All day' : fmtTime(e.startTime)}  ${e.title}');
      }
      for (final t in tasks) {
        out.write('\n${_taskLine(t)}');
      }
    }
    if (!any) return 'Nothing is scheduled for the next 7 days.';
    return out.toString();
  }

  String _spending() {
    final start = monthStart(now);
    final end = addMonths(start, 1);
    final prevStart = addMonths(start, -1);
    bool inRange(ExpenseRow e, DateTime a, DateTime b) => !e.date.isBefore(a) && e.date.isBefore(b);

    final month = data.expenses.where((e) => inRange(e, start, end)).toList();
    final spent = month.where((e) => !e.isIncome).fold<double>(0, (s, e) => s + e.amount);
    final income = month.where((e) => e.isIncome).fold<double>(0, (s, e) => s + e.amount);
    if (month.isEmpty) return 'No expenses or income recorded this month yet.';

    final out = StringBuffer('This month you spent ${money(spent)}');
    out.write(income > 0 ? ' and earned ${money(income)} (net ${money(income - spent)}).' : '.');

    // Same point last month, for a fair comparison.
    final prevCut = DateTime(prevStart.year, prevStart.month, now.day + 1);
    final prevEnd = prevCut.isBefore(start) ? prevCut : start;
    final prevSpent = data.expenses
        .where((e) => !e.isIncome && inRange(e, prevStart, prevEnd))
        .fold<double>(0, (s, e) => s + e.amount);
    if (prevSpent > 0) {
      final change = (spent - prevSpent) / prevSpent * 100;
      out.write('\nThat is ${change.abs().round()}% ${change >= 0 ? 'more' : 'less'} than at this point last month (${money(prevSpent)}).');
    }

    final byCat = <String, double>{};
    for (final e in month.where((e) => !e.isIncome)) {
      byCat[e.category] = (byCat[e.category] ?? 0.0) + e.amount;
    }
    final ranked = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (ranked.isNotEmpty) {
      out.write('\n\nTop categories');
      for (final c in ranked.take(3)) {
        out.write('\n• ${c.key}: ${money(c.value)} (${(c.value / spent * 100).round()}%)');
      }
    }

    final budgets = effectiveBudgets(data.budgets, now);
    final warnings = <String>[];
    for (final b in budgets.entries) {
      final used = byCat[b.key] ?? 0.0;
      if (b.value <= 0) continue;
      if (used > b.value) {
        warnings.add('• ${b.key} is over budget by ${money(used - b.value)}');
      } else if (used >= b.value * 0.8) {
        warnings.add('• ${b.key} has used ${(used / b.value * 100).round()}% of its budget');
      }
    }
    if (warnings.isNotEmpty) out.write('\n\nBudgets\n${warnings.join('\n')}');

    final biggest = month.where((e) => !e.isIncome).toList()..sort((a, b) => b.amount.compareTo(a.amount));
    if (biggest.isNotEmpty) {
      out.write('\n\nBiggest expense: ${biggest.first.description} (${money(biggest.first.amount)}, ${fmtDate(biggest.first.date, now: now)}).');
    }
    return out.toString();
  }

  String _habits() {
    final active = data.habits.where((h) => h.isActive).toList();
    if (active.isEmpty) return 'You are not tracking any habits yet. Add one under More > Habits.';
    final todayKey = dayKey(now);
    final rows = [
      for (final h in active)
        (h: h, cur: currentStreak(data.habitDays[h.id] ?? const {}, now), best: bestStreak(data.habitDays[h.id] ?? const {})),
    ]..sort((a, b) => b.cur.compareTo(a.cur));
    final done = active.where((h) => data.habitDays[h.id]?.contains(todayKey) ?? false).length;
    final out = StringBuffer('Today: $done of ${active.length} habits done.\n');
    for (final r in rows) {
      final doneToday = data.habitDays[r.h.id]?.contains(todayKey) ?? false;
      out.write('\n• ${r.h.name}: ${r.cur}-day streak (best ${r.best})${doneToday ? '' : ', not done today'}');
    }
    final atRisk = rows.where((r) => r.cur >= 3 && !(data.habitDays[r.h.id]?.contains(todayKey) ?? false)).toList();
    if (atRisk.isNotEmpty) {
      out.write('\n\nKeep the streak alive: ${atRisk.map((r) => r.h.name).join(', ')} still needs doing today.');
    }
    return out.toString();
  }

  String _goals() {
    final open = data.goals.where((g) => !g.isCompleted).toList()..sort((a, b) => a.targetDate.compareTo(b.targetDate));
    final doneCount = data.goals.length - open.length;
    if (data.goals.isEmpty) return 'No goals yet. Add one under More > Goals.';
    if (open.isEmpty) return 'All $doneCount goals are complete.';
    final out = StringBuffer('${open.length} active ${open.length == 1 ? 'goal' : 'goals'}${doneCount > 0 ? ', $doneCount completed' : ''}.\n');
    for (final g in open) {
      final p = (goalProgress(milestones: g.milestones, manual: g.progress, completed: false) * 100).round();
      final days = daysBetween(now, g.targetDate);
      final when = days < 0 ? '${-days} days past target' : (days == 0 ? 'due today' : '$days days left');
      out.write('\n• ${g.title}: $p%, $when');
    }
    final behind = open.where((g) {
      final total = daysBetween(g.createdAt, g.targetDate);
      if (total <= 0) return false;
      final elapsed = daysBetween(g.createdAt, now) / total;
      return elapsed > goalProgress(milestones: g.milestones, manual: g.progress, completed: false) + 0.25;
    }).toList();
    if (behind.isNotEmpty) out.write('\n\nBehind schedule: ${behind.map((g) => g.title).join(', ')}.');
    return out.toString();
  }

  int _focusMinutes(DateTime from, DateTime to) => data.focus
      .where((f) => !f.startedAt.isBefore(from) && f.startedAt.isBefore(to))
      .fold<int>(0, (s, f) => s + f.completedMinutes);

  String _focus() {
    final today = dateOnly(now);
    final todayMin = _focusMinutes(today, addDays(today, 1));
    final weekStart = addDays(today, -(today.weekday - 1));
    final weekMin = _focusMinutes(weekStart, addDays(today, 1));
    final sessions = data.focus.where((f) => !f.startedAt.isBefore(weekStart)).length;
    if (data.focus.isEmpty) return 'No focus sessions yet. Start one from More > Focus timer.';
    return 'Today: $todayMin min of focus.\nThis week: $weekMin min across $sessions ${sessions == 1 ? 'session' : 'sessions'}.'
        '${todayMin == 0 ? '\n\nA single 25-minute session is a good start.' : ''}';
  }

  String _journal() {
    final since = addDays(dateOnly(now), -13);
    final recent = data.journal.where((j) => !j.createdAt.isBefore(since)).toList();
    if (data.journal.isEmpty) return 'Your journal is empty. Write a first entry under More > Journal.';
    if (recent.isEmpty) return 'No journal entries in the last two weeks.';
    final moods = <String, int>{};
    for (final j in recent) {
      final m = j.mood;
      if (m != null && m.isNotEmpty) moods[m] = (moods[m] ?? 0) + 1;
    }
    final out = StringBuffer('${recent.length} ${recent.length == 1 ? 'entry' : 'entries'} in the last two weeks.');
    if (moods.isNotEmpty) {
      final ranked = moods.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      out.write('\nMost common mood: ${moodLabel(ranked.first.key)} (${ranked.first.value}×).');
      out.write('\nAll moods: ${ranked.map((e) => '${moodLabel(e.key)} ${e.value}').join(', ')}.');
    }
    final last = data.journal.first;
    out.write('\n\nLast entry: ${relativeDay(last.createdAt, now: now)}${last.title.isEmpty ? '' : ', "${last.title}"'}.');
    return out.toString();
  }

  String _notes() {
    if (data.notes.isEmpty) return 'You have no notes yet.';
    final pinned = data.notes.where((n) => n.isPinned).length;
    final withLists = data.notes.where((n) => decodeChecklist(n.checklist).any((i) => !i.done)).toList();
    final out = StringBuffer('${data.notes.length} notes${pinned > 0 ? ', $pinned pinned' : ''}.');
    if (withLists.isNotEmpty) {
      out.write('\n\nChecklists with open items');
      for (final n in withLists.take(5)) {
        final items = decodeChecklist(n.checklist);
        out.write('\n• ${n.title.isEmpty ? 'Untitled' : n.title}: ${items.where((i) => !i.done).length} left');
      }
    }
    return out.toString();
  }

  String _help() => 'I answer questions about your own Plania data, on this device. Try:\n'
      '• Plan my day\n'
      "• What's overdue?\n"
      '• My week ahead\n'
      '• How much did I spend this month?\n'
      '• How are my habit streaks?\n'
      '• Goal progress\n'
      '• Focus time this week\n'
      '• How has my mood been?';
}

/// Category -> limit in effect for [month] (the latest budget set on or before that month).
Map<String, double> effectiveBudgets(List<BudgetRow> budgets, DateTime month) {
  final cutoff = monthStart(month);
  final sorted = budgets.where((b) => !b.month.isAfter(cutoff)).toList()..sort((a, b) => a.month.compareTo(b.month));
  final map = <String, double>{};
  for (final b in sorted) {
    map[b.category] = b.limitAmount;
  }
  map.removeWhere((_, v) => v <= 0);
  return map;
}

/// Journal moods. 1.x stored emoji; those are shown as-is.
const Map<String, String> kMoods = {
  'great': 'Great',
  'good': 'Good',
  'okay': 'Okay',
  'low': 'Low',
  'rough': 'Rough',
};

String moodLabel(String mood) => kMoods[mood] ?? mood;
