import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plania/data/backup.dart';
import 'package:plania/data/database.dart';
import 'package:plania/data/repo.dart';
import 'package:plania/logic/reminder_actions.dart';
import 'package:plania/logic/rules.dart';
import 'package:plania/logic/tasks_view.dart';

class RecordingReminders implements ReminderScheduler {
  final synced = <String, DateTime?>{};
  final cancelled = <String>[];
  @override
  Future<void> syncTask(TaskRow task) async => synced[task.id] = task.isCompleted ? null : task.reminderAt;
  @override
  Future<void> cancelTask(String taskId) async => cancelled.add(taskId);
}

TaskRow _task(String id, {String? project, bool done = false, DateTime? due, String? parent, String title = 't'}) => TaskRow(
      id: id,
      userId: 'local',
      title: title,
      isCompleted: done,
      dueDate: due,
      priority: 1,
      project: project,
      labels: '',
      parentId: parent,
      isRecurring: false,
      recurrence: 'none',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

TaskCompletionRow _done(DateTime at) =>
    TaskCompletionRow(id: '${at.millisecondsSinceEpoch}', taskId: 'x', title: 'x', category: 'General', completedAt: at);

void main() {
  late AppDatabase db;
  late LifeRepo repo;
  late RecordingReminders reminders;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    reminders = RecordingReminders();
    repo = LifeRepo(db, reminders);
  });

  tearDown(() => db.close());

  group('categories', () {
    test('null and unknown projects count as General', () {
      expect(taskCategory(null), 'General');
      expect(taskCategory('Side project'), 'General');
      expect(taskCategory('Work'), 'Work');
    });

    test('open counts per category ignore done tasks and subtasks', () {
      final tasks = [
        _task('a', project: 'Work'),
        _task('b', project: 'Work', done: true),
        _task('c'),
        _task('d', project: 'Grocery'),
        _task('e', project: 'Work', parent: 'a'),
      ];
      final counts = openCountsByCategory(tasks);
      expect(counts, {'Personal': 0, 'Work': 1, 'Grocery': 1, 'School': 0, 'General': 1});
    });

    test('the category filter and the search work together', () {
      final tasks = [
        _task('a', project: 'Work', title: 'Write report'),
        _task('b', project: 'Work', title: 'Call client'),
        _task('c', project: 'Personal', title: 'Write card'),
        _task('d', project: 'Work', title: 'Report part', parent: 'a'),
      ];
      expect(filterTasks(tasks, category: 'Work').map((t) => t.id), ['a', 'b']);
      expect(filterTasks(tasks, query: 'write').map((t) => t.id), ['a', 'c']);
      expect(filterTasks(tasks, category: 'Work', query: 'WRITE').map((t) => t.id), ['a']);
      expect(filterTasks(tasks, category: 'School'), isEmpty);
    });
  });

  group('insights', () {
    test('streak, today, the 7-day bars and the weekly rate', () {
      final now = DateTime(2026, 11, 26, 15); // a Thursday
      final completions = [
        _done(DateTime(2026, 11, 26, 9)),
        _done(DateTime(2026, 11, 26, 10)),
        _done(DateTime(2026, 11, 25, 20)),
        _done(DateTime(2026, 11, 24, 8)),
        _done(DateTime(2026, 11, 21, 8)), // last week; the empty 22nd and 23rd end the streak
      ];
      final tasks = [
        _task('open-this-week', due: DateTime(2026, 11, 28)),
        _task('overdue', due: DateTime(2026, 11, 20)),
        _task('next-week', due: DateTime(2026, 12, 2)),
      ];
      final i = computeInsights(tasks, completions, now);
      expect(i.completedToday, 2);
      expect(i.streak, 3);
      expect(i.last7, [0, 1, 0, 0, 1, 1, 2]);
      expect(i.last7Labels.last, 'T');
      expect(i.weekDone, 4);
      expect(i.weekOpen, 1);
      expect(i.weekRate, closeTo(0.8, 0.001));
      expect(i.overdue, 1);
    });

    test('nothing yet today keeps yesterday\'s streak; a gap ends it', () {
      final now = DateTime(2026, 11, 26, 8);
      expect(computeInsights(const [], [_done(DateTime(2026, 11, 25, 9))], now).streak, 1);
      expect(computeInsights(const [], [_done(DateTime(2026, 11, 24, 9))], now).streak, 0);
      expect(computeInsights(const [], const [], now).weekRate, isNull);
    });

    test('every completion is logged, repeats included, and undo removes it', () async {
      final id = await repo.saveTask(
        TasksCompanion(title: const Value('Water plants'), recurrence: const Value('daily'), dueDate: Value(DateTime(2026, 11, 26)), project: const Value('Personal')),
      );
      await repo.setTaskDone(id, true);
      var log = await db.select(db.taskCompletions).get();
      expect(log, hasLength(1));
      expect(log.single.category, 'Personal');
      final next = (await repo.allTasks()).firstWhere((t) => t.id != id);
      await repo.setTaskDone(next.id, true);
      expect(await db.select(db.taskCompletions).get(), hasLength(2));
      await repo.setTaskDone(next.id, false);
      log = await db.select(db.taskCompletions).get();
      expect(log.single.taskId, id);
      // Subtasks are not counted.
      await repo.addSubtask(id, 'Kitchen');
      final sub = (await repo.allTasks()).firstWhere((t) => t.parentId == id);
      await repo.setTaskDone(sub.id, true);
      expect(await db.select(db.taskCompletions).get(), hasLength(1));
    });

    test('schema 7 migration backfills completed tasks from their last update', () async {
      final updated = DateTime(2026, 11, 20, 18).millisecondsSinceEpoch ~/ 1000;
      final old = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute('''CREATE TABLE tasks (id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, title TEXT NOT NULL,
              description TEXT, is_completed INTEGER NOT NULL DEFAULT 0, due_date INTEGER, priority INTEGER NOT NULL DEFAULT 1,
              project TEXT, labels TEXT NOT NULL DEFAULT '', parent_id TEXT, is_recurring INTEGER NOT NULL DEFAULT 0,
              recurrence TEXT NOT NULL DEFAULT 'none', reminder_at INTEGER, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)''');
            raw.execute("INSERT INTO tasks (id, user_id, title, is_completed, project, created_at, updated_at) VALUES ('t1', 'local', 'Done one', 1, 'Work', $updated, $updated)");
            raw.execute("INSERT INTO tasks (id, user_id, title, is_completed, project, created_at, updated_at) VALUES ('t2', 'local', 'Old project', 1, 'Garden', $updated, $updated)");
            raw.execute("INSERT INTO tasks (id, user_id, title, is_completed, created_at, updated_at) VALUES ('t3', 'local', 'Still open', 0, $updated, $updated)");
            raw.execute("INSERT INTO tasks (id, user_id, title, is_completed, parent_id, created_at, updated_at) VALUES ('t4', 'local', 'Sub', 1, 't1', $updated, $updated)");
            raw.execute('PRAGMA user_version = 6');
          },
        ),
      );
      addTearDown(old.close);
      final log = await old.select(old.taskCompletions).get();
      expect(log.map((c) => c.taskId).toSet(), {'t1', 't2'});
      expect(log.firstWhere((c) => c.taskId == 't1').category, 'Work');
      expect(log.firstWhere((c) => c.taskId == 't2').category, 'General');
      expect(log.first.completedAt, DateTime(2026, 11, 20, 18));
      expect((await old.select(old.tasks).get()), hasLength(4));
    });

    test('completions are in backups, and older backups rebuild them', () async {
      final id = await repo.saveTask(const TasksCompanion(title: Value('Ship it'), project: Value('Work')));
      await repo.setTaskDone(id, true);
      final json = await Backup(db).export();
      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await Backup(other).import(json);
      expect((await other.select(other.taskCompletions).get()).single.taskId, id);

      final legacy = jsonDecode(json) as Map<String, dynamic>..remove('completions');
      final third = AppDatabase(NativeDatabase.memory());
      addTearDown(third.close);
      await Backup(third).import(jsonEncode(legacy));
      final rebuilt = await third.select(third.taskCompletions).get();
      expect(rebuilt.single.taskId, id);
      expect(rebuilt.single.category, 'Work');
    });
  });

  group('reminder actions', () {
    test('payloads and the stale-notification guard', () {
      expect(taskIdFromPayload(reminderPayload('abc')), 'abc');
      expect(taskIdFromPayload(null), isNull);
      expect(taskIdFromPayload('task:'), isNull);
      expect(taskIdFromPayload('other'), isNull);
      expect(reminderOutcome(null), ReminderOutcome.missing);
      expect(reminderOutcome(_task('a', done: true)), ReminderOutcome.alreadyDone);
      expect(reminderOutcome(_task('a')), ReminderOutcome.apply);
    });

    test('Mark done completes once, repeats roll over, a second tap changes nothing', () async {
      final id = await repo.saveTask(
        TasksCompanion(
          title: const Value('Stretch'),
          recurrence: const Value('daily'),
          dueDate: Value(DateTime(2026, 11, 26, 9)),
          reminderAt: Value(DateTime(2026, 11, 26, 9)),
        ),
      );
      expect(await repo.markDoneFromReminder(id), ReminderOutcome.apply);
      expect((await repo.task(id))!.isCompleted, isTrue);
      final tasks = await repo.allTasks();
      expect(tasks, hasLength(2));
      final next = tasks.firstWhere((t) => t.id != id);
      expect(next.dueDate, DateTime(2026, 11, 27, 9));
      expect(next.reminderAt, DateTime(2026, 11, 27, 9));
      // A stale notification (or a double tap) does nothing more.
      expect(await repo.markDoneFromReminder(id), ReminderOutcome.alreadyDone);
      expect(await repo.allTasks(), hasLength(2));
      expect(await db.select(db.taskCompletions).get(), hasLength(1));
      expect(await repo.markDoneFromReminder('gone'), ReminderOutcome.missing);
    });

    test('Snooze moves the reminder 10 minutes on', () async {
      final id = await repo.saveTask(TasksCompanion(title: const Value('Call'), reminderAt: Value(DateTime(2026, 11, 26, 9))));
      final now = DateTime(2026, 11, 26, 9, 1);
      expect(await repo.snoozeFromReminder(id, now), ReminderOutcome.apply);
      expect((await repo.task(id))!.reminderAt, DateTime(2026, 11, 26, 9, 11));
      expect(reminders.synced[id], DateTime(2026, 11, 26, 9, 11));
      await repo.setTaskDone(id, true);
      expect(await repo.snoozeFromReminder(id, now), ReminderOutcome.alreadyDone);
    });
  });

  group('swipe undo and notes to tasks', () {
    test('a deleted task comes back with its subtasks and reminder', () async {
      final at = DateTime(2030, 1, 1, 9);
      final id = await repo.saveTask(TasksCompanion(title: const Value('Trip'), reminderAt: Value(at), project: const Value('Personal')));
      await repo.addSubtask(id, 'Book hotel');
      final snapshot = await repo.deleteTaskForUndo(id);
      expect(snapshot, hasLength(2));
      expect(await repo.allTasks(), isEmpty);
      reminders.synced.clear();
      await repo.restoreTasks(snapshot);
      final back = await repo.allTasks();
      expect(back.map((t) => t.title).toSet(), {'Trip', 'Book hotel'});
      expect(back.firstWhere((t) => t.id == id).project, 'Personal');
      expect(reminders.synced[id], at);
    });

    test('note lines and unchecked items become task titles', () {
      final checklist = encodeChecklist(const [CheckItem('Milk'), CheckItem('Eggs', done: true), CheckItem('Bread')]);
      expect(noteToTaskTitles('Buy stamps\n\n- Post letter\n  * Call bank  \n[x] Done thing\n1. Book dentist', checklist), [
        'Buy stamps',
        'Post letter',
        'Call bank',
        'Book dentist',
        'Milk',
        'Bread',
      ]);
      expect(noteToTaskTitles('  \n', ''), isEmpty);
      expect(noteToTaskTitles('Same\nSame', ''), ['Same']);
    });

    test('creating tasks from a note adds open General tasks', () async {
      final n = await repo.createTasks(noteToTaskTitles('Buy stamps\nPost letter\nCall bank', ''));
      expect(n, 3);
      final tasks = await repo.allTasks();
      expect(tasks.every((t) => !t.isCompleted && taskCategory(t.project) == 'General'), isTrue);
      expect(openCountsByCategory(tasks)['General'], 3);
    });
  });
}
