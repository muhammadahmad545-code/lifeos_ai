import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plania/data/backup.dart';
import 'package:plania/data/backup_crypto.dart';
import 'package:plania/data/database.dart';
import 'package:plania/data/repo.dart';
import 'package:plania/logic/rules.dart';
import 'package:plania/logic/today_widget.dart';

void main() {
  late AppDatabase db;
  late LifeRepo repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LifeRepo(db);
  });

  tearDown(() => db.close());

  Future<List<ExpenseRow>> expenses() => db.select(db.expenses).get();

  group('recurring expenses and income', () {
    test('occurrences keep their day and clamp to short months', () {
      final start = DateTime(2026, 1, 31, 12);
      expect(recurringOccurrence(start, 'monthly', 1), DateTime(2026, 2, 28, 12));
      expect(recurringOccurrence(start, 'monthly', 2), DateTime(2026, 3, 31, 12));
      expect(recurringOccurrence(DateTime(2026, 11, 2), 'weekly', 3), DateTime(2026, 11, 23));
      expect(dueOccurrences(start, 'monthly', 0, DateTime(2026, 3, 30)), [0, 1]);
      expect(dueOccurrences(start, 'monthly', 2, DateTime(2026, 3, 30)), isEmpty);
      expect(recurringScheduleLabel(DateTime(2026, 1, 2), 'monthly'), 'Monthly on the 2nd');
      expect(recurringScheduleLabel(DateTime(2026, 11, 23), 'weekly'), 'Weekly on Monday');
    });

    test('a monthly entry dated today posts once and counts in this month', () async {
      final now = DateTime(2026, 11, 23, 9);
      await repo.addRecurring(
        description: 'Rent',
        amount: 1200,
        category: 'Bills',
        isIncome: false,
        frequency: 'monthly',
        start: DateTime(2026, 11, 23, 12),
        now: now,
      );
      var rows = await expenses();
      expect(rows, hasLength(1));
      expect(rows.single.description, 'Rent');
      expect(rows.single.recurringId, isNotNull);
      final monthTotal = rows.where((e) => e.date.year == 2026 && e.date.month == 11 && !e.isIncome).fold<double>(0, (s, e) => s + e.amount);
      expect(monthTotal, 1200);

      // Catch-up is idempotent: app start, resume and midnight may all run it.
      expect(await repo.postDueRecurring(now), 0);
      expect(await repo.postDueRecurring(now), 0);
      expect(await expenses(), hasLength(1));

      // Three months later, the missed occurrences are posted once each.
      expect(await repo.postDueRecurring(DateTime(2027, 2, 23, 8)), 3);
      expect(await repo.postDueRecurring(DateTime(2027, 2, 23, 8)), 0);
      rows = await expenses();
      expect(rows, hasLength(4));
      expect(rows.map((e) => e.date).toSet(), {
        DateTime(2026, 11, 23, 12),
        DateTime(2026, 12, 23, 12),
        DateTime(2027, 1, 23, 12),
        DateTime(2027, 2, 23, 12),
      });
    });

    test('even if the rule index is rewound, an occurrence is never posted twice', () async {
      final id = await repo.addRecurring(
        description: 'Salary',
        amount: 3000,
        category: 'Salary',
        isIncome: true,
        frequency: 'monthly',
        start: DateTime(2026, 10, 1, 12),
        now: DateTime(2026, 11, 2),
      );
      expect(await expenses(), hasLength(2));
      await (db.update(db.recurringEntries)..where((r) => r.id.equals(id))).write(const RecurringEntriesCompanion(nextIndex: Value(0)));
      expect(await repo.postDueRecurring(DateTime(2026, 11, 2)), 0);
      expect(await expenses(), hasLength(2));
      expect((await expenses()).every((e) => e.isIncome), isTrue);
    });

    test('a future start date posts nothing until its day', () async {
      await repo.addRecurring(
        description: 'Gym',
        amount: 30,
        category: 'Health',
        isIncome: false,
        frequency: 'weekly',
        start: DateTime(2026, 11, 30, 12),
        now: DateTime(2026, 11, 23),
      );
      expect(await expenses(), isEmpty);
      expect(await repo.postDueRecurring(DateTime(2026, 12, 7, 0, 1)), 2);
    });

    test('paused entries skip their occurrences; resuming does not back-fill', () async {
      final id = await repo.addRecurring(
        description: 'Music',
        amount: 10,
        category: 'Entertainment',
        isIncome: false,
        frequency: 'monthly',
        start: DateTime(2026, 9, 5, 12),
        now: DateTime(2026, 9, 5),
      );
      await repo.setRecurringPaused(id, true, now: DateTime(2026, 9, 6));
      expect(await repo.postDueRecurring(DateTime(2026, 12, 1)), 0);
      await repo.setRecurringPaused(id, false, now: DateTime(2026, 12, 1));
      expect(await expenses(), hasLength(1));
      expect(await repo.postDueRecurring(DateTime(2026, 12, 5)), 1);
      expect((await expenses()).map((e) => e.date.month).toSet(), {9, 12});
    });

    test('deleting a rule keeps the entries it posted', () async {
      final id = await repo.addRecurring(
        description: 'Internet',
        amount: 40,
        category: 'Bills',
        isIncome: false,
        frequency: 'monthly',
        start: DateTime(2026, 11, 1, 12),
        now: DateTime(2026, 11, 23),
      );
      await repo.deleteRecurring(id);
      expect(await repo.allRecurring(), isEmpty);
      final rows = await expenses();
      expect(rows, hasLength(1));
      expect(rows.single.recurringId, isNull);
    });

    test('an existing entry can become recurring without back-filling', () async {
      await repo.saveExpense(description: 'Phone', amount: 20, category: 'Bills', date: DateTime(2026, 8, 10, 12), isIncome: false);
      final entry = (await expenses()).single;
      await repo.makeRecurring(entry, 'monthly', now: DateTime(2026, 11, 23));
      final rows = await expenses();
      expect(rows, hasLength(1));
      expect(rows.single.recurringId, isNotNull);
      expect(await repo.postDueRecurring(DateTime(2026, 12, 10)), 1);
    });

    test('schema 6 migration keeps existing expenses', () async {
      final old = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              'CREATE TABLE expenses (id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, description TEXT NOT NULL, '
              'amount REAL NOT NULL, category TEXT NOT NULL, date INTEGER NOT NULL, is_income INTEGER NOT NULL DEFAULT 0, '
              "tags TEXT NOT NULL DEFAULT '', receipt_path TEXT, created_at INTEGER NOT NULL)",
            );
            raw.execute("INSERT INTO expenses VALUES ('e1', 'local', 'Rent', 900.0, 'Bills', 1767268800, 0, '', NULL, 1767268800)");
            raw.execute('PRAGMA user_version = 5');
          },
        ),
      );
      final rows = await old.select(old.expenses).get();
      expect(rows.single.description, 'Rent');
      expect(rows.single.amount, 900);
      expect(rows.single.recurringId, isNull);
      expect(await old.select(old.recurringEntries).get(), isEmpty);
      await LifeRepo(old).addRecurring(
        description: 'Rent',
        amount: 900,
        category: 'Bills',
        isIncome: false,
        frequency: 'monthly',
        start: DateTime(2026, 11, 1, 12),
        now: DateTime(2026, 11, 2),
      );
      expect(await old.select(old.expenses).get(), hasLength(2));
      await old.close();
    });
  });

  group('passphrase-encrypted backup', () {
    Future<void> seed() async {
      await repo.saveExpense(description: 'Lunch', amount: 12.5, category: 'Food', date: DateTime(2026, 11, 20, 12), isIncome: false);
      await repo.addRecurring(
        description: 'Rent',
        amount: 1200,
        category: 'Bills',
        isIncome: false,
        frequency: 'monthly',
        start: DateTime(2026, 11, 1, 12),
        now: DateTime(2026, 11, 2),
      );
    }

    test('uses strong defaults', () {
      expect(BackupCrypto.defaultIterations, greaterThanOrEqualTo(200000));
    });

    test('round trip: encrypt, detect, decrypt with the passphrase and import', () async {
      await seed();
      final plain = await Backup(db).export();
      final sealed = await BackupCrypto.encrypt(plain, 'correct horse battery');
      expect(BackupCrypto.isEncrypted(sealed), isTrue);
      expect(BackupCrypto.isEncrypted(plain), isFalse);
      expect(sealed.contains('Lunch'), isFalse);
      final header = jsonDecode(sealed) as Map<String, dynamic>;
      expect(header['cipher'], 'AES-256-GCM');
      expect(header['iterations'], BackupCrypto.defaultIterations);
      // A protected file is never mistaken for a plain one.
      expect(() => Backup.inspect(sealed), throwsA(isA<BackupFormatException>()));

      final opened = await BackupCrypto.decrypt(sealed, 'correct horse battery');
      expect(opened, plain);
      final other = AppDatabase(NativeDatabase.memory());
      expect(Backup.inspect(opened)['recurring'], 1);
      await Backup(other).import(opened);
      expect((await other.select(other.expenses).get()).map((e) => e.description).toSet(), {'Lunch', 'Rent'});
      expect(await other.select(other.recurringEntries).get(), hasLength(1));
      await other.close();
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('a wrong passphrase fails clearly and changes nothing', () async {
      await seed();
      final sealed = await BackupCrypto.encrypt(await Backup(db).export(), 'right one', iterations: 2000);
      final other = AppDatabase(NativeDatabase.memory());
      Future<void> importWith(String passphrase) async {
        final text = await BackupCrypto.decrypt(sealed, passphrase);
        await Backup(other).import(text);
      }

      await expectLater(importWith('wrong one'), throwsA(isA<BackupPassphraseException>()));
      expect(const BackupPassphraseException().message, contains('Wrong passphrase'));
      expect(await other.select(other.expenses).get(), isEmpty);
      // A tampered file is rejected the same way.
      final tampered = jsonDecode(sealed) as Map<String, dynamic>;
      final data = base64Decode(tampered['data'] as String);
      data[0] ^= 1;
      tampered['data'] = base64Encode(data);
      await expectLater(BackupCrypto.decrypt(jsonEncode(tampered), 'right one'), throwsA(isA<BackupPassphraseException>()));
      await importWith('right one');
      expect(await other.select(other.expenses).get(), hasLength(2));
      await other.close();
    });

    test('plain 2.0 backups (format 1) still import', () async {
      final legacy = jsonEncode({
        'app': 'lifeos',
        'format': 1,
        'exportedAt': '2026-11-01T10:00:00.000',
        'expenses': [
          {
            'id': 'old-1',
            'userId': 'local',
            'description': 'Coffee',
            'amount': 3.5,
            'category': 'Food',
            'date': DateTime(2026, 10, 30, 12).millisecondsSinceEpoch,
            'isIncome': false,
            'tags': '',
            'receiptPath': null,
            'createdAt': DateTime(2026, 10, 30, 12).millisecondsSinceEpoch,
          },
        ],
      });
      expect(BackupCrypto.isEncrypted(legacy), isFalse);
      expect(Backup.inspect(legacy)['expenses'], 1);
      expect(await Backup(db).import(legacy), 1);
      final rows = await expenses();
      expect(rows.single.description, 'Coffee');
      expect(rows.single.recurringId, isNull);
    });
  });

  group('Today widget data', () {
    test('counts due tasks, habits and keeps tomorrow ready', () async {
      final now = DateTime(2026, 11, 23, 10);
      await repo.saveTask(TasksCompanion(title: const Value('Overdue thing'), dueDate: Value(DateTime(2026, 11, 20))));
      await repo.saveTask(TasksCompanion(title: const Value('Pay rent'), dueDate: Value(DateTime(2026, 11, 23)), priority: const Value(3)));
      await repo.saveTask(TasksCompanion(title: const Value('Call mum'), dueDate: Value(DateTime(2026, 11, 24))));
      await repo.saveTask(const TasksCompanion(title: Value('Someday')));
      final h1 = await repo.saveHabit(name: 'Water');
      await repo.saveHabit(name: 'Read');
      await repo.setHabitDone(h1, now, true);
      await repo.saveEvent(CalendarEventsCompanion(
        title: const Value('Past'),
        startTime: Value(DateTime(2026, 11, 23, 8)),
        endTime: Value(DateTime(2026, 11, 23, 9)),
      ));
      await repo.saveEvent(CalendarEventsCompanion(
        title: const Value('Team lunch'),
        startTime: Value(DateTime(2026, 11, 23, 13)),
        endTime: Value(DateTime(2026, 11, 23, 14)),
      ));
      final logs = await db.select(db.habitLogs).get();

      final tasks = await repo.allTasks();
      final habits = await db.select(db.habits).get();
      final events = await db.select(db.calendarEvents).get();
      final data = todayWidgetData(
        tasks: tasks,
        habits: habits,
        habitDays: {for (final l in logs) l.habitId: {l.day}},
        events: events,
        now: now,
        locked: false,
      );
      final days = data['days'] as Map;
      final today = days['2026-11-23'] as Map;
      expect(today['tasks'], 2);
      expect(today['titles'], ['Pay rent', 'Overdue thing']);
      expect(today['habitsDone'], 1);
      expect(data['habitsTotal'], 2);
      final tomorrow = days['2026-11-24'] as Map;
      expect(tomorrow['tasks'], 3);
      expect(tomorrow['habitsDone'], 0);
      final evs = data['events'] as List;
      expect((evs.first as Map)['title'], 'Team lunch');
      expect(evs, hasLength(1));
      // Valid JSON for the native side.
      expect(jsonDecode(jsonEncode(data)), isA<Map>());

      final locked = todayWidgetData(tasks: tasks, habits: habits, habitDays: const {}, events: events, now: now, locked: true);
      expect(((locked['days'] as Map)['2026-11-23'] as Map)['titles'], isEmpty);
      expect(((locked['events'] as List).first as Map)['title'], '');
    });
  });
}
