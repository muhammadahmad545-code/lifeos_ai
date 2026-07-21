import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/assistant/data/assistant_repository_impl.dart';
import '../../features/assistant/domain/assistant_repository.dart';
import '../../features/assistant/domain/chat_message.dart';
import '../../features/assistant/domain/lifeos_ai_engine.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/calendar/data/calendar_repository_impl.dart';
import '../../features/calendar/domain/calendar_event.dart';
import '../../features/calendar/domain/calendar_repository.dart';
import '../../features/expenses/data/expense_repository_impl.dart';
import '../../features/expenses/domain/expense.dart';
import '../../features/expenses/domain/expense_repository.dart';
import '../../features/files/data/file_repository_impl.dart';
import '../../features/files/domain/app_file.dart';
import '../../features/files/domain/file_repository.dart';
import '../../features/focus/data/focus_repository_impl.dart';
import '../../features/focus/domain/focus_repository.dart';
import '../../features/focus/domain/focus_session.dart';
import '../../features/goals/data/goal_repository_impl.dart';
import '../../features/goals/domain/goal.dart';
import '../../features/goals/domain/goal_repository.dart';
import '../../features/habits/data/habit_repository_impl.dart';
import '../../features/habits/domain/habit.dart';
import '../../features/habits/domain/habit_repository.dart';
import '../../features/health/data/health_repository_impl.dart';
import '../../features/health/domain/health_log.dart';
import '../../features/health/domain/health_repository.dart';
import '../../features/journal/data/journal_repository_impl.dart';
import '../../features/journal/domain/journal_entry.dart';
import '../../features/journal/domain/journal_repository.dart';
import '../../features/notes/data/note_repository_impl.dart';
import '../../features/notes/domain/note.dart';
import '../../features/notes/domain/note_repository.dart';
import '../../features/notifications/data/notification_repository_impl.dart';
import '../../features/notifications/domain/app_notification.dart';
import '../../features/notifications/domain/notification_repository.dart';
import '../../features/tasks/data/task_repository_impl.dart';
import '../../features/tasks/domain/task.dart';
import '../../features/tasks/domain/task_repository.dart';
import 'database_provider.dart';
import 'providers.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepositoryImpl(ref.watch(appDatabaseProvider));
});

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepositoryImpl(ref.watch(appDatabaseProvider));
});

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepositoryImpl(ref.watch(appDatabaseProvider));
});

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return HabitRepositoryImpl(ref.watch(appDatabaseProvider));
});

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepositoryImpl(ref.watch(appDatabaseProvider));
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepositoryImpl(ref.watch(appDatabaseProvider));
});

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepositoryImpl(ref.watch(appDatabaseProvider));
});

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return HealthRepositoryImpl(ref.watch(appDatabaseProvider));
});

final focusRepositoryProvider = Provider<FocusRepository>((ref) {
  return FocusRepositoryImpl(ref.watch(appDatabaseProvider));
});

final fileRepositoryProvider = Provider<FileRepository>((ref) {
  return FileRepositoryImpl(ref.watch(appDatabaseProvider));
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(ref.watch(appDatabaseProvider));
});

final assistantRepositoryProvider = Provider<AssistantRepository>((ref) {
  return AssistantRepositoryImpl(ref.watch(appDatabaseProvider));
});

final lifeOsAiEngineProvider = Provider<LifeOsAiEngine>((ref) {
  return const LifeOsAiEngine();
});

String? _userId(Ref ref) {
  final AsyncValue<AuthUser?> session = ref.watch(authSessionProvider);
  return session.valueOrNull?.id;
}

final tasksProvider = FutureProvider((ref) async {
  final String? userId = _userId(ref);
  if (userId == null) {
    return const [];
  }
  return ref.watch(taskRepositoryProvider).getTasks(userId);
});

final notesProvider = FutureProvider((ref) async {
  final String? userId = _userId(ref);
  if (userId == null) {
    return const [];
  }
  return ref.watch(noteRepositoryProvider).getNotes(userId);
});

final calendarEventsProvider = FutureProvider((ref) async {
  final String? userId = _userId(ref);
  if (userId == null) {
    return const [];
  }
  return ref.watch(calendarRepositoryProvider).getEventsForDay(userId, DateTime.now());
});

final habitsProvider = FutureProvider((ref) async {
  final String? userId = _userId(ref);
  if (userId == null) {
    return const [];
  }
  return ref.watch(habitRepositoryProvider).getHabits(userId);
});

final journalEntriesProvider = FutureProvider((ref) async {
  final String? userId = _userId(ref);
  if (userId == null) {
    return const [];
  }
  return ref.watch(journalRepositoryProvider).getEntries(userId);
});

final expensesProvider = FutureProvider((ref) async {
  final String? userId = _userId(ref);
  if (userId == null) {
    return const [];
  }
  return ref.watch(expenseRepositoryProvider).getExpenses(userId);
});

final goalsProvider = FutureProvider((ref) async {
  final String? userId = _userId(ref);
  if (userId == null) {
    return const [];
  }
  return ref.watch(goalRepositoryProvider).getGoals(userId);
});

// ---------------------------------------------------------------------------
// Stream providers — reactive, always in sync with the Drift database.
// ---------------------------------------------------------------------------

final watchTasksProvider = StreamProvider<List<Task>>((ref) {
  final String? userId = _userId(ref);
  if (userId == null) {
    return Stream<List<Task>>.value(const <Task>[]);
  }
  return ref.watch(taskRepositoryProvider).watchTasks(userId);
});

final watchNotesProvider = StreamProvider<List<Note>>((ref) {
  final String? userId = _userId(ref);
  if (userId == null) {
    return Stream<List<Note>>.value(const <Note>[]);
  }
  return ref.watch(noteRepositoryProvider).watchNotes(userId);
});

final watchCalendarEventsProvider = StreamProvider<List<CalendarEvent>>((ref) {
  final String? userId = _userId(ref);
  if (userId == null) {
    return Stream<List<CalendarEvent>>.value(const <CalendarEvent>[]);
  }
  return ref.watch(calendarRepositoryProvider).watchEvents(userId);
});

final watchHabitsProvider = StreamProvider<List<Habit>>((ref) {
  final String? userId = _userId(ref);
  if (userId == null) {
    return Stream<List<Habit>>.value(const <Habit>[]);
  }
  return ref.watch(habitRepositoryProvider).watchHabits(userId);
});

final watchJournalEntriesProvider = StreamProvider<List<JournalEntry>>((ref) {
  final String? userId = _userId(ref);
  if (userId == null) {
    return Stream<List<JournalEntry>>.value(const <JournalEntry>[]);
  }
  return ref.watch(journalRepositoryProvider).watchEntries(userId);
});

final watchExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final String? userId = _userId(ref);
  if (userId == null) {
    return Stream<List<Expense>>.value(const <Expense>[]);
  }
  return ref.watch(expenseRepositoryProvider).watchExpenses(userId);
});

final watchBudgetsProvider = StreamProvider<List<Budget>>((ref) {
  final String? userId = _userId(ref);
  if (userId == null) {
    return Stream<List<Budget>>.value(const <Budget>[]);
  }
  return ref.watch(expenseRepositoryProvider).watchBudgets(userId);
});

final watchGoalsProvider = StreamProvider<List<Goal>>((ref) {
  final String? userId = _userId(ref);
  if (userId == null) {
    return Stream<List<Goal>>.value(const <Goal>[]);
  }
  return ref.watch(goalRepositoryProvider).watchGoals(userId);
});

final watchFilesProvider = StreamProvider<List<AppFile>>((ref) {
  final String? userId = _userId(ref);
  if (userId == null) {
    return Stream<List<AppFile>>.value(const <AppFile>[]);
  }
  return ref.watch(fileRepositoryProvider).watchFiles(userId);
});

final watchNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final String? userId = _userId(ref);
  if (userId == null) {
    return Stream<List<AppNotification>>.value(const <AppNotification>[]);
  }
  return ref.watch(notificationRepositoryProvider).watchNotifications(userId);
});

final watchChatMessagesProvider = StreamProvider<List<ChatMessage>>((ref) {
  final String? userId = _userId(ref);
  if (userId == null) {
    return Stream<List<ChatMessage>>.value(const <ChatMessage>[]);
  }
  return ref.watch(assistantRepositoryProvider).watchMessages(userId);
});

final watchFocusSessionsProvider = StreamProvider<List<FocusSession>>((ref) {
  final String? userId = _userId(ref);
  if (userId == null) {
    return Stream<List<FocusSession>>.value(const <FocusSession>[]);
  }
  return ref.watch(focusRepositoryProvider).watchSessions(userId);
});

final focusStatsProvider = FutureProvider<FocusStats>((ref) async {
  final String? userId = _userId(ref);
  if (userId == null) {
    return const FocusStats(totalMinutes: 0, completedCount: 0);
  }
  ref.watch(watchFocusSessionsProvider);
  return ref.watch(focusRepositoryProvider).getStats(userId);
});

/// Family of streams keyed by [HealthLogType], one per health tracker section.
final healthLogsProvider = StreamProvider.family<List<HealthLog>, HealthLogType>((ref, type) {
  final String? userId = _userId(ref);
  if (userId == null) {
    return Stream<List<HealthLog>>.value(const <HealthLog>[]);
  }
  return ref.watch(healthRepositoryProvider).watchByType(userId, type);
});
