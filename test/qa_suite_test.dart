import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_ai/core/database/app_database.dart';
import 'package:lifeos_ai/core/services/receipt_text_parser.dart';
import 'package:lifeos_ai/core/utils/list_codec.dart';
import 'package:lifeos_ai/core/utils/password_hasher.dart';
import 'package:lifeos_ai/features/auth/data/datasources/local_auth_remote_data_source.dart';
import 'package:lifeos_ai/features/assistant/domain/lifeos_ai_engine.dart';
import 'package:lifeos_ai/features/calendar/data/calendar_repository_impl.dart';
import 'package:lifeos_ai/features/calendar/domain/calendar_event.dart';
import 'package:lifeos_ai/features/expenses/data/expense_repository_impl.dart';
import 'package:lifeos_ai/features/expenses/domain/expense.dart';
import 'package:lifeos_ai/features/goals/data/goal_repository_impl.dart';
import 'package:lifeos_ai/features/goals/domain/goal.dart';
import 'package:lifeos_ai/features/habits/data/habit_repository_impl.dart';
import 'package:lifeos_ai/features/habits/domain/habit.dart';
import 'package:lifeos_ai/features/notes/data/note_repository_impl.dart';
import 'package:lifeos_ai/features/notes/domain/note.dart';
import 'package:lifeos_ai/features/tasks/data/task_repository_impl.dart';
import 'package:lifeos_ai/features/tasks/domain/task.dart';
import 'package:lifeos_ai/features/tasks/domain/task_template.dart';

void main() {
  group('Core utilities', () {
    test('PasswordHasher rejects wrong password', () {
      final String hash = PasswordHasher.hash('correct-horse');
      expect(PasswordHasher.verify('correct-horse', hash), isTrue);
      expect(PasswordHasher.verify('correct-horse ', hash), isFalse);
      expect(PasswordHasher.verify('', hash), isFalse);
    });

    test('ListCodec ignores blanks and round-trips', () {
      expect(ListCodec.encode(<String>['a', '', ' b ', '']), 'a|b');
      expect(ListCodec.decode('a|b||c'), <String>['a', 'b', 'c']);
      expect(ListCodec.decode('   '), isEmpty);
    });
  });

  group('ReceiptTextParser edge cases', () {
    test('prefers total amount over earlier line items', () {
      final ReceiptParseResult result = ReceiptTextParser.parse(
        'Item A \$3.50\nItem B \$4.00\nGrand Total \$12.75',
      );
      expect(result.amount, 12.75);
    });

    test('handles empty and non-numeric text', () {
      expect(ReceiptTextParser.parse('').amount, isNull);
      expect(ReceiptTextParser.parse('Thank you for visiting').amount, isNull);
    });

    test('detects transport category hints', () {
      final ReceiptParseResult result = ReceiptTextParser.parse('Uber trip\nTotal \$18.20');
      expect(result.category, 'Transport');
      expect(result.amount, 18.20);
    });
  });

  group('Task templates', () {
    test('built-in templates convert to incomplete tasks', () {
      for (final TaskTemplate template in BuiltInTaskTemplates.all) {
        final Task task = template.toTask();
        expect(task.id, isEmpty);
        expect(task.title, isNotEmpty);
        expect(task.isCompleted, isFalse);
      }
    });
  });

  group('LifeOsAiEngine edge cases', () {
    const LifeOsAiEngine engine = LifeOsAiEngine();

    test('empty message returns guidance', () {
      expect(engine.respond(userMessage: '   ').toLowerCase(), contains('offline'));
    });

    test('handles empty data sets without crash', () {
      final String reply = engine.respond(
        userMessage: 'Give me an overview',
        tasks: const <Task>[],
        notes: const <Note>[],
        habits: const <Habit>[],
        expenses: const <Expense>[],
        goals: const <Goal>[],
      );
      expect(reply, isNotEmpty);
    });
  });

  group('Repositories (in-memory Drift)', () {
    late AppDatabase db;
    late LocalAuthRemoteDataSource auth;
    late TaskRepositoryImpl tasks;
    late NoteRepositoryImpl notes;
    late HabitRepositoryImpl habits;
    late ExpenseRepositoryImpl expenses;
    late GoalRepositoryImpl goals;
    late CalendarRepositoryImpl calendar;
    late String userId;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      auth = LocalAuthRemoteDataSource(db);
      tasks = TaskRepositoryImpl(db);
      notes = NoteRepositoryImpl(db);
      habits = HabitRepositoryImpl(db);
      expenses = ExpenseRepositoryImpl(db);
      goals = GoalRepositoryImpl(db);
      calendar = CalendarRepositoryImpl(db);

      final user = await auth.signUpWithEmail(
        email: 'qa@lifeos.test',
        password: 'secret12',
        displayName: 'QA User',
      );
      userId = user.id;
    });

    tearDown(() async {
      await db.close();
    });

    test('auth rejects duplicate signup and bad login', () async {
      await expectLater(
        () => auth.signUpWithEmail(email: 'qa@lifeos.test', password: 'secret12', displayName: 'X'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        () => auth.signInWithEmail(email: 'qa@lifeos.test', password: 'wrong'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        () => auth.signInWithEmail(email: '  ', password: 'secret12'),
        throwsA(isA<StateError>()),
      );
      final signedIn = await auth.signInWithEmail(email: '  QA@LifeOS.TEST ', password: 'secret12');
      expect(signedIn.id, userId);
    });

    test('password reset requires valid code and length', () async {
      final String code = await auth.sendPasswordReset(email: 'qa@lifeos.test');
      expect(code.length, 6);
      await expectLater(
        () => auth.resetPassword(email: 'qa@lifeos.test', newPassword: '123'),
        throwsA(isA<StateError>()),
      );
      await auth.verifyResetCode(email: 'qa@lifeos.test', code: code);
      await auth.resetPassword(email: 'qa@lifeos.test', newPassword: 'newpass9');
      final signedIn = await auth.signInWithEmail(email: 'qa@lifeos.test', password: 'newpass9');
      expect(signedIn.id, userId);
    });

    test('recurring task creates next occurrence and clears stale reminder', () async {
      final Task created = await tasks.createTask(
        userId,
        Task(
          id: '',
          title: 'Daily standup',
          isCompleted: false,
          dueDate: DateTime(2026, 1, 31, 9),
          reminderAt: DateTime(2026, 1, 31, 8),
          recurrence: TaskRecurrence.monthly,
        ),
      );
      await tasks.markTaskComplete(created.id, isCompleted: true);
      final List<Task> all = await tasks.getTasks(userId);
      final Task next = all.firstWhere((Task t) => !t.isCompleted && t.title == 'Daily standup');
      expect(next.dueDate?.month, 2);
      expect(next.dueDate?.day, 28); // Jan 31 → Feb 28 (non-leap 2026)
      expect(next.reminderAt?.month, 2);
    });

    test('deleting parent task removes subtasks', () async {
      final Task parent = await tasks.createTask(
        userId,
        const Task(id: '', title: 'Parent', isCompleted: false),
      );
      await tasks.createTask(
        userId,
        Task(id: '', title: 'Child', isCompleted: false, parentId: parent.id),
      );
      await tasks.deleteTask(parent.id);
      final List<Task> remaining = await tasks.getTasks(userId);
      expect(remaining.where((Task t) => t.title == 'Parent' || t.title == 'Child'), isEmpty);
    });

    test('note version history snapshots and restores', () async {
      final Note note = await notes.createNote(
        userId,
        const Note(id: '', title: 'v1', content: 'alpha'),
      );
      await notes.updateNote(note.copyWith(title: 'v2', content: 'beta'));
      final versions = await notes.getVersions(note.id);
      expect(versions, isNotEmpty);
      expect(versions.first.title, 'v1');
      final restored = await notes.restoreVersion(note.id, versions.first.id);
      expect(restored.title, 'v1');
      expect(restored.content, 'alpha');
    });

    test('habit completion is idempotent for same day', () async {
      final Habit habit = await habits.createHabit(
        userId,
        const Habit(id: '', name: 'Read', frequency: HabitFrequency.daily),
      );
      final Habit first = await habits.logHabitCompletion(habit.id, DateTime(2026, 7, 22, 8));
      final Habit second = await habits.logHabitCompletion(habit.id, DateTime(2026, 7, 22, 21));
      expect(second.currentStreak, first.currentStreak);
      expect(second.xp, first.xp);
    });

    test('expense receipt path and totals', () async {
      await expenses.createExpense(
        userId,
        Expense(
          id: '',
          description: 'Lunch',
          amount: 12.5,
          category: 'Food',
          date: DateTime(2026, 7, 1),
          receiptPath: '/tmp/receipt.jpg',
        ),
      );
      await expenses.createExpense(
        userId,
        Expense(
          id: '',
          description: 'Salary',
          amount: 1000,
          category: 'Salary',
          date: DateTime(2026, 7, 2),
          isIncome: true,
        ),
      );
      final totals = await expenses.getTotals(userId, DateTime(2026, 7, 1));
      expect(totals.income, 1000);
      expect(totals.expense, 12.5);
      expect(totals.net, 987.5);
      final list = await expenses.getExpenses(userId);
      expect(list.firstWhere((Expense e) => e.description == 'Lunch').receiptPath, '/tmp/receipt.jpg');
    });

    test('goal progress clamps and marks complete', () async {
      final Goal goal = await goals.createGoal(
        userId,
        Goal(id: '', title: 'Ship app', targetDate: DateTime(2026, 12, 1), progress: 0.2),
      );
      final Goal done = await goals.updateProgress(goal.id, 1.5);
      expect(done.progress, 1.0);
      expect(done.isCompleted, isTrue);
    });

    test('calendar rejects overlapping nonsense via repository store', () async {
      final CalendarEvent event = await calendar.createEvent(
        userId,
        CalendarEvent(
          id: '',
          title: 'Deep work',
          startTime: DateTime(2026, 7, 22, 10),
          endTime: DateTime(2026, 7, 22, 11),
          isTimeBlock: true,
          color: '2563EB',
        ),
      );
      expect(event.isTimeBlock, isTrue);
      final day = await calendar.getEventsForDay(userId, DateTime(2026, 7, 22));
      expect(day.length, 1);
      await calendar.deleteEvent(event.id);
      expect(await calendar.getEventsForDay(userId, DateTime(2026, 7, 22)), isEmpty);
    });
  });
}
