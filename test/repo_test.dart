import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/data/backup.dart';
import 'package:lifeos/data/database.dart';
import 'package:lifeos/data/repo.dart';
import 'package:lifeos/logic/dates.dart';

class RecordingReminders implements ReminderScheduler {
  final synced = <String>[];
  final cancelled = <String>[];
  @override
  Future<void> syncTask(TaskRow task) async => synced.add(task.id);
  @override
  Future<void> cancelTask(String taskId) async => cancelled.add(taskId);
}

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

  test('tasks: create, complete, search data and delete with subtasks', () async {
    final id = await repo.saveTask(const TasksCompanion(title: Value('Buy oat milk')));
    await repo.addSubtask(id, 'Check fridge');
    var tasks = await repo.allTasks();
    expect(tasks, hasLength(2));
    expect(tasks.every((t) => t.userId == kLocalUserId), isTrue);
    expect(reminders.synced, contains(id));

    await repo.setTaskDone(id, true);
    expect((await repo.task(id))!.isCompleted, isTrue);

    await repo.deleteTask(id);
    tasks = await repo.allTasks();
    expect(tasks, isEmpty);
    expect(reminders.cancelled, contains(id));
  });

  test('completing a repeating task schedules the next one, undo removes it', () async {
    final due = DateTime(2026, 1, 31, 9);
    final id = await repo.saveTask(
      TasksCompanion(
        title: const Value('Pay rent'),
        dueDate: Value(due),
        recurrence: const Value('monthly'),
        reminderAt: Value(due.subtract(const Duration(hours: 1))),
      ),
    );
    await repo.setTaskDone(id, true);
    var open = (await repo.allTasks()).where((t) => !t.isCompleted).toList();
    expect(open, hasLength(1));
    expect(open.single.dueDate, DateTime(2026, 2, 28, 9));
    expect(open.single.reminderAt, DateTime(2026, 2, 28, 8));

    await repo.setTaskDone(id, false);
    open = (await repo.allTasks()).where((t) => !t.isCompleted).toList();
    expect(open.map((t) => t.id), [id]);
  });

  test('habits: check-ins update streak columns and can be undone', () async {
    final id = await repo.saveHabit(name: 'Read');
    final today = DateTime.now();
    await repo.setHabitDone(id, addDays(today, -1), true);
    await repo.setHabitDone(id, today, true);
    await repo.setHabitDone(id, today, true); // twice is harmless
    var h = await (db.select(db.habits)..where((t) => t.id.equals(id))).getSingle();
    expect(h.currentStreak, 2);
    expect(h.longestStreak, 2);

    await repo.setHabitDone(id, today, false);
    h = await (db.select(db.habits)..where((t) => t.id.equals(id))).getSingle();
    expect(h.currentStreak, 1);
    expect((await db.select(db.habitLogs).get()), hasLength(1));

    await repo.deleteHabit(id);
    expect(await db.select(db.habitLogs).get(), isEmpty);
  });

  test('notes and expenses persist', () async {
    final noteId = await repo.saveNote(title: 'Groceries', content: 'for the week', checklist: '', pinned: true);
    await repo.saveNote(id: noteId, title: 'Groceries', content: 'for the weekend', checklist: '', pinned: false);
    final note = (await db.select(db.notes).get()).single;
    expect(note.content, 'for the weekend');
    expect(note.isPinned, isFalse);

    await repo.saveExpense(description: 'Lunch', amount: 12.5, category: 'Food', date: DateTime(2026, 11, 3), isIncome: false);
    await repo.setBudget('Food', DateTime(2026, 11, 20), 100);
    await repo.setBudget('Food', DateTime(2026, 11, 2), 120); // same month replaces
    expect((await db.select(db.expenses).get()).single.amount, 12.5);
    final budgets = await db.select(db.budgets).get();
    expect(budgets, hasLength(1));
    expect(budgets.single.limitAmount, 120);
    expect(budgets.single.month, DateTime(2026, 11));
  });

  test('backup round-trips into an empty database', () async {
    final taskId = await repo.saveTask(TasksCompanion(title: const Value('Backup me'), dueDate: Value(DateTime(2026, 5, 1))));
    final habitId = await repo.saveHabit(name: 'Walk');
    await repo.setHabitDone(habitId, DateTime(2026, 5, 1), true);
    await repo.saveNote(title: 'N', content: 'body', checklist: '[{"t":"a","d":true}]', pinned: false);
    final json = await Backup(db).export();

    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    expect(Backup.inspect(json)['tasks'], 1);
    final n = await Backup(other).import(json);
    expect(n, 4);
    final t = (await other.select(other.tasks).get()).single;
    expect(t.id, taskId);
    expect(t.dueDate, DateTime(2026, 5, 1));
    expect((await other.select(other.notes).get()).single.checklist, '[{"t":"a","d":true}]');
    // Importing again updates instead of duplicating.
    await Backup(other).import(json);
    expect(await other.select(other.tasks).get(), hasLength(1));
  });

  test('backup rejects other files', () {
    expect(() => Backup.inspect('{"app":"other"}'), throwsA(isA<BackupFormatException>()));
    expect(() => Backup.inspect('nope'), throwsA(isA<BackupFormatException>()));
  });

  test('upgrading a 1.x database keeps rows and moves them to the local user', () async {
    final last = DateTime(2026, 11, 16).millisecondsSinceEpoch ~/ 1000;
    final created = DateTime(2026, 1, 1).millisecondsSinceEpoch ~/ 1000;
    final old = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('CREATE TABLE users (id TEXT NOT NULL PRIMARY KEY, email TEXT NOT NULL, password_hash TEXT NOT NULL)');
          raw.execute('''CREATE TABLE tasks (id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, title TEXT NOT NULL,
            description TEXT, is_completed INTEGER NOT NULL DEFAULT 0, due_date INTEGER, priority INTEGER NOT NULL DEFAULT 1,
            project TEXT, labels TEXT NOT NULL DEFAULT '', parent_id TEXT, is_recurring INTEGER NOT NULL DEFAULT 0,
            recurrence TEXT NOT NULL DEFAULT 'none', reminder_at INTEGER, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)''');
          raw.execute('''CREATE TABLE notes (id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, title TEXT NOT NULL,
            content TEXT NOT NULL, color TEXT, tags TEXT NOT NULL DEFAULT '', folder TEXT, is_pinned INTEGER NOT NULL DEFAULT 0,
            is_favorite INTEGER NOT NULL DEFAULT 0, is_archived INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL)''');
          raw.execute('''CREATE TABLE habits (id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, name TEXT NOT NULL,
            description TEXT, frequency INTEGER NOT NULL DEFAULT 0, color TEXT, current_streak INTEGER NOT NULL DEFAULT 0,
            longest_streak INTEGER NOT NULL DEFAULT 0, xp INTEGER NOT NULL DEFAULT 0, level INTEGER NOT NULL DEFAULT 1,
            is_active INTEGER NOT NULL DEFAULT 1, last_completed_at INTEGER, created_at INTEGER NOT NULL)''');
          raw.execute("INSERT INTO users VALUES ('u1', 'a@b.c', 'hash')");
          raw.execute("INSERT INTO tasks (id, user_id, title, created_at, updated_at) VALUES ('t1', 'u1', 'Old task', $created, $created)");
          raw.execute("INSERT INTO notes (id, user_id, title, content, created_at, updated_at) VALUES ('n1', 'u2', 'Old note', 'x', $created, $created)");
          raw.execute("INSERT INTO habits (id, user_id, name, current_streak, last_completed_at, created_at) VALUES ('h1', 'u1', 'Run', 3, $last, $created)");
          raw.execute('PRAGMA user_version = 4');
        },
      ),
    );
    addTearDown(old.close);
    final oldRepo = LifeRepo(old);
    final tasks = await oldRepo.allTasks();
    expect(tasks.single.title, 'Old task');
    expect(tasks.single.userId, kLocalUserId);
    final notes = await old.select(old.notes).get();
    expect(notes.single.userId, kLocalUserId);
    expect(notes.single.checklist, '');
    final logs = await old.select(old.habitLogs).get();
    expect(logs.map((l) => l.day).toSet(), {'2026-11-16', '2026-11-15', '2026-11-14'});
    final tables = await old.customSelect("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'users'").get();
    expect(tables, isEmpty);
  });
}
