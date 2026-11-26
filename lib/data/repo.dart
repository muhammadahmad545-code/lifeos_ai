import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../logic/dates.dart';
import '../logic/reminder_actions.dart';
import '../logic/rules.dart';
import 'database.dart';

/// Keeps scheduled notifications in step with tasks. The app passes the real notification
/// service; tests pass [NoReminders].
abstract class ReminderScheduler {
  Future<void> syncTask(TaskRow task);
  Future<void> cancelTask(String taskId);
}

class NoReminders implements ReminderScheduler {
  const NoReminders();
  @override
  Future<void> syncTask(TaskRow task) async {}
  @override
  Future<void> cancelTask(String taskId) async {}
}

const _uuid = Uuid();
String newId() => _uuid.v4();

/// All reads and writes go through here. Streams keep every screen live.
class LifeRepo {
  LifeRepo(this.db, [this.reminders = const NoReminders()]);

  final AppDatabase db;
  final ReminderScheduler reminders;

  // ---------------------------------------------------------------------------
  // Tasks
  // ---------------------------------------------------------------------------

  Stream<List<TaskRow>> watchTasks() => (db.select(db.tasks)
        ..where((t) => t.userId.equals(kLocalUserId))
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
      .watch();

  Future<List<TaskRow>> allTasks() =>
      (db.select(db.tasks)..where((t) => t.userId.equals(kLocalUserId))).get();

  Future<TaskRow?> task(String id) => (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Inserts a new task (when [id] is null) or updates an existing one, then syncs its reminder.
  Future<String> saveTask(TasksCompanion data, {String? id}) async {
    final now = DateTime.now();
    final taskId = id ?? newId();
    if (id == null) {
      await db.into(db.tasks).insert(
            data.copyWith(
              id: Value(taskId),
              userId: const Value(kLocalUserId),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    } else {
      await (db.update(db.tasks)..where((t) => t.id.equals(taskId))).write(data.copyWith(updatedAt: Value(now)));
    }
    final row = await task(taskId);
    if (row != null) await reminders.syncTask(row);
    return taskId;
  }

  /// Completes or reopens a task. Completing a repeating task creates its next occurrence;
  /// reopening it removes that occurrence again if it is still untouched.
  Future<void> setTaskDone(String id, bool done) async {
    final row = await task(id);
    if (row == null || row.isCompleted == done) return;
    final now = DateTime.now();
    await db.transaction(() async {
      await (db.update(db.tasks)..where((t) => t.id.equals(id)))
          .write(TasksCompanion(isCompleted: Value(done), updatedAt: Value(now)));
      if (row.parentId != null) return;
      if (done) {
        await db.into(db.taskCompletions).insert(
              TaskCompletionsCompanion.insert(
                id: newId(),
                taskId: id,
                title: row.title,
                category: Value(taskCategory(row.project)),
                completedAt: now,
              ),
            );
      } else {
        // Undo: drop the latest completion of this task.
        final last = await (db.select(db.taskCompletions)
              ..where((c) => c.taskId.equals(id))
              ..orderBy([(c) => OrderingTerm.desc(c.completedAt)])
              ..limit(1))
            .getSingleOrNull();
        if (last != null) await (db.delete(db.taskCompletions)..where((c) => c.id.equals(last.id))).go();
      }
    });
    final updated = await task(id);
    if (updated != null) await reminders.syncTask(updated);

    final rec = row.recurrence;
    if (rec == 'none' || row.parentId != null) return;
    final base = row.dueDate ?? dateOnly(DateTime.now());
    final next = nextDue(base, rec);
    if (done) {
      DateTime? nextReminder;
      if (row.reminderAt != null) nextReminder = next.subtract(base.difference(row.reminderAt!));
      await saveTask(
        TasksCompanion(
          title: Value(row.title),
          description: Value(row.description),
          dueDate: Value(next),
          priority: Value(row.priority),
          project: Value(row.project),
          labels: Value(row.labels),
          isRecurring: const Value(true),
          recurrence: Value(rec),
          reminderAt: Value(nextReminder),
        ),
      );
    } else {
      final spawned = await (db.select(db.tasks)
            ..where(
              (t) =>
                  t.title.equals(row.title) &
                  t.recurrence.equals(rec) &
                  t.isCompleted.equals(false) &
                  t.dueDate.equals(next) &
                  t.parentId.isNull(),
            ))
          .get();
      for (final s in spawned) {
        if (s.id != id) await deleteTask(s.id);
      }
    }
  }

  Future<void> deleteTask(String id) async {
    final children = await (db.select(db.tasks)..where((t) => t.parentId.equals(id))).get();
    for (final c in children) {
      await deleteTask(c.id);
    }
    await (db.delete(db.tasks)..where((t) => t.id.equals(id))).go();
    await reminders.cancelTask(id);
  }

  /// Deletes a task with its subtasks and returns them, so the delete can be undone with
  /// [restoreTasks].
  Future<List<TaskRow>> deleteTaskForUndo(String id) async {
    final snapshot = <TaskRow>[];
    Future<void> collect(String taskId) async {
      final row = await task(taskId);
      if (row == null) return;
      snapshot.add(row);
      final children = await (db.select(db.tasks)..where((t) => t.parentId.equals(taskId))).get();
      for (final c in children) {
        await collect(c.id);
      }
    }

    await collect(id);
    await deleteTask(id);
    return snapshot;
  }

  /// Puts deleted tasks back exactly as they were, reminders included.
  Future<void> restoreTasks(List<TaskRow> rows) async {
    await db.transaction(() async {
      for (final r in rows) {
        await db.into(db.tasks).insertOnConflictUpdate(r);
      }
    });
    for (final r in rows) {
      await reminders.syncTask(r);
    }
  }

  /// Creates open tasks with these titles (used by "Turn lines into tasks"). Returns how many.
  Future<int> createTasks(List<String> titles) async {
    var n = 0;
    for (final t in titles) {
      if (t.trim().isEmpty) continue;
      await saveTask(TasksCompanion(title: Value(t.trim())));
      n++;
    }
    return n;
  }

  Stream<List<TaskCompletionRow>> watchCompletions() =>
      (db.select(db.taskCompletions)..orderBy([(c) => OrderingTerm.desc(c.completedAt)])).watch();

  /// "Mark done" from a reminder notification. Completes the task (a repeating one schedules its
  /// next round) unless the notification is stale.
  Future<ReminderOutcome> markDoneFromReminder(String taskId) async {
    final outcome = reminderOutcome(await task(taskId));
    if (outcome == ReminderOutcome.apply) await setTaskDone(taskId, true);
    if (outcome == ReminderOutcome.alreadyDone) await reminders.cancelTask(taskId);
    return outcome;
  }

  /// "Snooze 10 min" from a reminder notification: moves the reminder, which reschedules it.
  Future<ReminderOutcome> snoozeFromReminder(String taskId, DateTime now) async {
    final outcome = reminderOutcome(await task(taskId));
    if (outcome == ReminderOutcome.apply) {
      await saveTask(TasksCompanion(reminderAt: Value(now.add(kSnooze))), id: taskId);
    }
    return outcome;
  }

  Future<void> addSubtask(String parentId, String title) async {
    if (title.trim().isEmpty) return;
    await saveTask(TasksCompanion(title: Value(title.trim()), parentId: Value(parentId)));
  }

  // ---------------------------------------------------------------------------
  // Notes
  // ---------------------------------------------------------------------------

  Stream<List<NoteRow>> watchNotes() => (db.select(db.notes)
        ..where((n) => n.userId.equals(kLocalUserId) & n.isArchived.equals(false))
        ..orderBy([(n) => OrderingTerm.desc(n.isPinned), (n) => OrderingTerm.desc(n.updatedAt)]))
      .watch();

  Future<String> saveNote({
    String? id,
    required String title,
    required String content,
    required String checklist,
    required bool pinned,
  }) async {
    final now = DateTime.now();
    if (id == null) {
      final noteId = newId();
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: noteId,
              userId: kLocalUserId,
              title: title,
              content: content,
              checklist: Value(checklist),
              isPinned: Value(pinned),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return noteId;
    }
    await (db.update(db.notes)..where((n) => n.id.equals(id))).write(
          NotesCompanion(
            title: Value(title),
            content: Value(content),
            checklist: Value(checklist),
            isPinned: Value(pinned),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  Future<void> setNotePinned(String id, bool pinned) =>
      (db.update(db.notes)..where((n) => n.id.equals(id))).write(NotesCompanion(isPinned: Value(pinned)));

  Future<void> setNoteChecklist(String id, String checklist) => (db.update(db.notes)..where((n) => n.id.equals(id)))
      .write(NotesCompanion(checklist: Value(checklist), updatedAt: Value(DateTime.now())));

  Future<void> deleteNote(String id) => (db.delete(db.notes)..where((n) => n.id.equals(id))).go();

  // ---------------------------------------------------------------------------
  // Calendar
  // ---------------------------------------------------------------------------

  Stream<List<CalendarEventRow>> watchEvents() => (db.select(db.calendarEvents)
        ..where((e) => e.userId.equals(kLocalUserId))
        ..orderBy([(e) => OrderingTerm.asc(e.startTime)]))
      .watch();

  Future<void> saveEvent(CalendarEventsCompanion data, {String? id}) async {
    if (id == null) {
      await db.into(db.calendarEvents).insert(
            data.copyWith(
              id: Value(newId()),
              userId: const Value(kLocalUserId),
              createdAt: Value(DateTime.now()),
            ),
          );
    } else {
      await (db.update(db.calendarEvents)..where((e) => e.id.equals(id))).write(data);
    }
  }

  Future<void> deleteEvent(String id) => (db.delete(db.calendarEvents)..where((e) => e.id.equals(id))).go();

  // ---------------------------------------------------------------------------
  // Habits
  // ---------------------------------------------------------------------------

  Stream<List<HabitRow>> watchHabits() => (db.select(db.habits)
        ..where((h) => h.userId.equals(kLocalUserId))
        ..orderBy([(h) => OrderingTerm.desc(h.isActive), (h) => OrderingTerm.asc(h.createdAt)]))
      .watch();

  Stream<List<HabitLogRow>> watchHabitLogs() => db.select(db.habitLogs).watch();

  Future<String> saveHabit({String? id, required String name, String? description, bool active = true}) async {
    if (id == null) {
      final habitId = newId();
      await db.into(db.habits).insert(
            HabitsCompanion.insert(
              id: habitId,
              userId: kLocalUserId,
              name: name,
              description: Value(description),
              isActive: Value(active),
              createdAt: DateTime.now(),
            ),
          );
      return habitId;
    }
    await (db.update(db.habits)..where((h) => h.id.equals(id)))
        .write(HabitsCompanion(name: Value(name), description: Value(description), isActive: Value(active)));
    return id;
  }

  Future<void> deleteHabit(String id) async {
    await (db.delete(db.habitLogs)..where((l) => l.habitId.equals(id))).go();
    await (db.delete(db.habits)..where((h) => h.id.equals(id))).go();
  }

  /// Marks [day] done or not done for a habit and refreshes the cached streak columns.
  Future<void> setHabitDone(String habitId, DateTime day, bool done) async {
    final key = dayKey(day);
    if (done) {
      await db.into(db.habitLogs).insert(
            HabitLogsCompanion.insert(habitId: habitId, day: key, createdAt: DateTime.now()),
            mode: InsertMode.insertOrIgnore,
          );
    } else {
      await (db.delete(db.habitLogs)..where((l) => l.habitId.equals(habitId) & l.day.equals(key))).go();
    }
    final logs = await (db.select(db.habitLogs)..where((l) => l.habitId.equals(habitId))).get();
    final days = {for (final l in logs) l.day};
    final sorted = days.toList()..sort();
    await (db.update(db.habits)..where((h) => h.id.equals(habitId))).write(
          HabitsCompanion(
            currentStreak: Value(currentStreak(days, DateTime.now())),
            longestStreak: Value(bestStreak(days)),
            lastCompletedAt: Value(sorted.isEmpty ? null : parseDayKey(sorted.last)),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // Journal
  // ---------------------------------------------------------------------------

  Stream<List<JournalEntryRow>> watchJournal() => (db.select(db.journalEntries)
        ..where((j) => j.userId.equals(kLocalUserId))
        ..orderBy([(j) => OrderingTerm.desc(j.createdAt)]))
      .watch();

  Future<void> saveJournal({String? id, required String title, required String content, String? mood, DateTime? date}) async {
    final now = DateTime.now();
    if (id == null) {
      await db.into(db.journalEntries).insert(
            JournalEntriesCompanion.insert(
              id: newId(),
              userId: kLocalUserId,
              title: title,
              content: content,
              mood: Value(mood),
              createdAt: date ?? now,
              updatedAt: now,
            ),
          );
    } else {
      await (db.update(db.journalEntries)..where((j) => j.id.equals(id))).write(
            JournalEntriesCompanion(
              title: Value(title),
              content: Value(content),
              mood: Value(mood),
              createdAt: date == null ? const Value.absent() : Value(date),
              updatedAt: Value(now),
            ),
          );
    }
  }

  Future<void> deleteJournal(String id) => (db.delete(db.journalEntries)..where((j) => j.id.equals(id))).go();

  // ---------------------------------------------------------------------------
  // Expenses and budgets
  // ---------------------------------------------------------------------------

  Stream<List<ExpenseRow>> watchExpenses() => (db.select(db.expenses)
        ..where((e) => e.userId.equals(kLocalUserId))
        ..orderBy([(e) => OrderingTerm.desc(e.date), (e) => OrderingTerm.desc(e.createdAt)]))
      .watch();

  Future<void> saveExpense({
    String? id,
    required String description,
    required double amount,
    required String category,
    required DateTime date,
    required bool isIncome,
  }) async {
    if (id == null) {
      await db.into(db.expenses).insert(
            ExpensesCompanion.insert(
              id: newId(),
              userId: kLocalUserId,
              description: description,
              amount: amount,
              category: category,
              date: date,
              isIncome: Value(isIncome),
              createdAt: DateTime.now(),
            ),
          );
    } else {
      await (db.update(db.expenses)..where((e) => e.id.equals(id))).write(
            ExpensesCompanion(
              description: Value(description),
              amount: Value(amount),
              category: Value(category),
              date: Value(date),
              isIncome: Value(isIncome),
            ),
          );
    }
  }

  Future<ExpenseRow?> expense(String id) => (db.select(db.expenses)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<void> deleteExpense(String id) => (db.delete(db.expenses)..where((e) => e.id.equals(id))).go();

  // ---------------------------------------------------------------------------
  // Recurring expenses and income
  // ---------------------------------------------------------------------------

  Stream<List<RecurringRow>> watchRecurring() => (db.select(db.recurringEntries)
        ..where((r) => r.userId.equals(kLocalUserId))
        ..orderBy([(r) => OrderingTerm.asc(r.isPaused), (r) => OrderingTerm.asc(r.createdAt)]))
      .watch();

  Future<List<RecurringRow>> allRecurring() =>
      (db.select(db.recurringEntries)..where((r) => r.userId.equals(kLocalUserId))).get();

  /// The id of the expense posted for occurrence [index] of a rule. Being deterministic, the
  /// same occurrence can never be inserted twice.
  static String occurrenceId(String ruleId, int index) => 'rec-$ruleId-$index';

  /// Creates a recurring entry whose first occurrence is [start], then posts whatever is due.
  Future<String> addRecurring({
    required String description,
    required double amount,
    required String category,
    required bool isIncome,
    required String frequency,
    required DateTime start,
    DateTime? now,
  }) async {
    final id = newId();
    await db.into(db.recurringEntries).insert(
          RecurringEntriesCompanion.insert(
            id: id,
            userId: kLocalUserId,
            description: description,
            amount: amount,
            category: category,
            isIncome: Value(isIncome),
            frequency: frequency,
            startDate: start,
            createdAt: DateTime.now(),
          ),
        );
    await postDueRecurring(now);
    return id;
  }

  /// Turns an existing entry into the first occurrence of a new recurring rule. Later
  /// occurrences post from today on; the ones between the entry's date and today are not
  /// back-filled (the user has usually recorded those already).
  Future<String> makeRecurring(ExpenseRow entry, String frequency, {DateTime? now}) async {
    final n = now ?? DateTime.now();
    final id = newId();
    await db.transaction(() async {
      await db.into(db.recurringEntries).insert(
            RecurringEntriesCompanion.insert(
              id: id,
              userId: kLocalUserId,
              description: entry.description,
              amount: entry.amount,
              category: entry.category,
              isIncome: Value(entry.isIncome),
              frequency: frequency,
              startDate: entry.date,
              nextIndex: Value(firstOccurrenceFrom(entry.date, frequency, 1, n)),
              createdAt: n,
            ),
          );
      await (db.update(db.expenses)..where((e) => e.id.equals(entry.id))).write(ExpensesCompanion(recurringId: Value(id)));
    });
    await postDueRecurring(n);
    return id;
  }

  /// Posts every occurrence whose day has come, for all active rules, in one transaction.
  /// Safe to call any number of times (app start, resume, midnight): each occurrence has a
  /// fixed id and the rule's next index only moves forward. Returns the entries added.
  Future<int> postDueRecurring([DateTime? now]) {
    final n = now ?? DateTime.now();
    return db.transaction(() async {
      var posted = 0;
      final rules = await (db.select(db.recurringEntries)
            ..where((r) => r.userId.equals(kLocalUserId) & r.isPaused.equals(false)))
          .get();
      for (final r in rules) {
        final due = dueOccurrences(r.startDate, r.frequency, r.nextIndex, n);
        if (due.isEmpty) continue;
        for (final i in due) {
          final rowId = occurrenceId(r.id, i);
          final exists = await (db.select(db.expenses)..where((e) => e.id.equals(rowId))).getSingleOrNull();
          if (exists != null) continue;
          await db.into(db.expenses).insert(
                ExpensesCompanion.insert(
                  id: rowId,
                  userId: kLocalUserId,
                  description: r.description,
                  amount: r.amount,
                  category: r.category,
                  date: recurringOccurrence(r.startDate, r.frequency, i),
                  isIncome: Value(r.isIncome),
                  recurringId: Value(r.id),
                  createdAt: n,
                ),
                mode: InsertMode.insertOrIgnore,
              );
          posted++;
        }
        await (db.update(db.recurringEntries)..where((x) => x.id.equals(r.id)))
            .write(RecurringEntriesCompanion(nextIndex: Value(due.last + 1)));
      }
      return posted;
    });
  }

  /// Pauses or resumes a rule. Occurrences that fall while it is paused are skipped, not
  /// posted later.
  Future<void> setRecurringPaused(String id, bool paused, {DateTime? now}) async {
    final n = now ?? DateTime.now();
    final r = await (db.select(db.recurringEntries)..where((x) => x.id.equals(id))).getSingleOrNull();
    if (r == null || r.isPaused == paused) return;
    await (db.update(db.recurringEntries)..where((x) => x.id.equals(id))).write(
          RecurringEntriesCompanion(
            isPaused: Value(paused),
            nextIndex: paused ? const Value.absent() : Value(firstOccurrenceFrom(r.startDate, r.frequency, r.nextIndex, n)),
          ),
        );
    if (!paused) await postDueRecurring(n);
  }

  /// Deletes a rule. Entries it already posted stay, as ordinary entries.
  Future<void> deleteRecurring(String id) => db.transaction(() async {
        await (db.update(db.expenses)..where((e) => e.recurringId.equals(id)))
            .write(const ExpensesCompanion(recurringId: Value(null)));
        await (db.delete(db.recurringEntries)..where((r) => r.id.equals(id))).go();
      });

  Stream<List<BudgetRow>> watchBudgets() => (db.select(db.budgets)
        ..where((b) => b.userId.equals(kLocalUserId))
        ..orderBy([(b) => OrderingTerm.asc(b.month)]))
      .watch();

  /// Sets the monthly limit for a category from [month] on. A limit of 0 removes it.
  Future<void> setBudget(String category, DateTime month, double limit) async {
    final start = monthStart(month);
    await (db.delete(db.budgets)
          ..where((b) => b.userId.equals(kLocalUserId) & b.category.equals(category) & b.month.equals(start)))
        .go();
    await db.into(db.budgets).insert(
          BudgetsCompanion.insert(
            id: newId(),
            userId: kLocalUserId,
            category: category,
            limitAmount: limit < 0 ? 0 : limit,
            month: start,
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // Goals
  // ---------------------------------------------------------------------------

  Stream<List<GoalRow>> watchGoals() => (db.select(db.goals)
        ..where((g) => g.userId.equals(kLocalUserId))
        ..orderBy([(g) => OrderingTerm.asc(g.isCompleted), (g) => OrderingTerm.asc(g.targetDate)]))
      .watch();

  Future<void> saveGoal({
    String? id,
    required String title,
    String? description,
    required DateTime targetDate,
    required double progress,
    required String milestones,
    required bool completed,
  }) async {
    if (id == null) {
      await db.into(db.goals).insert(
            GoalsCompanion.insert(
              id: newId(),
              userId: kLocalUserId,
              title: title,
              description: Value(description),
              targetDate: targetDate,
              progress: Value(progress),
              milestones: Value(milestones),
              isCompleted: Value(completed),
              createdAt: DateTime.now(),
            ),
          );
    } else {
      await (db.update(db.goals)..where((g) => g.id.equals(id))).write(
            GoalsCompanion(
              title: Value(title),
              description: Value(description),
              targetDate: Value(targetDate),
              progress: Value(progress),
              milestones: Value(milestones),
              isCompleted: Value(completed),
            ),
          );
    }
  }

  Future<void> setGoalMilestones(String id, String milestones) =>
      (db.update(db.goals)..where((g) => g.id.equals(id))).write(GoalsCompanion(milestones: Value(milestones)));

  Future<void> deleteGoal(String id) => (db.delete(db.goals)..where((g) => g.id.equals(id))).go();

  // ---------------------------------------------------------------------------
  // Focus
  // ---------------------------------------------------------------------------

  Stream<List<FocusSessionRow>> watchFocus() => (db.select(db.focusSessions)
        ..where((f) => f.userId.equals(kLocalUserId))
        ..orderBy([(f) => OrderingTerm.desc(f.startedAt)]))
      .watch();

  Future<void> addFocusSession({
    required int plannedMinutes,
    required int minutes,
    required bool completed,
    required DateTime startedAt,
    required DateTime endedAt,
  }) =>
      db.into(db.focusSessions).insert(
            FocusSessionsCompanion.insert(
              id: newId(),
              userId: kLocalUserId,
              durationMinutes: plannedMinutes,
              completedMinutes: Value(minutes),
              completed: Value(completed),
              startedAt: startedAt,
              endedAt: Value(endedAt),
            ),
          );
}
