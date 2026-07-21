import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/calendar/domain/calendar_repository.dart';
import '../../features/expenses/domain/expense_repository.dart';
import '../../features/goals/domain/goal_repository.dart';
import '../../features/habits/domain/habit_repository.dart';
import '../../features/journal/domain/journal_repository.dart';
import '../../features/notes/domain/note_repository.dart';
import '../../features/tasks/domain/task.dart';
import '../../features/tasks/domain/task_repository.dart';

class BackupService {
  BackupService({
    required this.taskRepository,
    required this.noteRepository,
    required this.calendarRepository,
    required this.habitRepository,
    required this.journalRepository,
    required this.expenseRepository,
    required this.goalRepository,
  });

  final TaskRepository taskRepository;
  final NoteRepository noteRepository;
  final CalendarRepository calendarRepository;
  final HabitRepository habitRepository;
  final JournalRepository journalRepository;
  final ExpenseRepository expenseRepository;
  final GoalRepository goalRepository;

  Future<File> exportToFile(String userId) async {
    final DateTime now = DateTime.now();
    final List<Task> tasks = await taskRepository.getTasks(userId);
    final notes = await noteRepository.getNotes(userId);
    final events = await calendarRepository.getEventsInRange(
      userId,
      now.subtract(const Duration(days: 365)),
      now.add(const Duration(days: 365)),
    );
    final habits = await habitRepository.getHabits(userId);
    final journal = await journalRepository.getEntries(userId);
    final expenses = await expenseRepository.getExpenses(userId);
    final goals = await goalRepository.getGoals(userId);

    final Map<String, dynamic> payload = <String, dynamic>{
      'app': 'LIFEOS AI',
      'exportedAt': now.toIso8601String(),
      'userId': userId,
      'tasks': tasks
          .map(
            (Task t) => <String, dynamic>{
              'id': t.id,
              'title': t.title,
              'description': t.description,
              'isCompleted': t.isCompleted,
              'priority': t.priority.name,
              'dueDate': t.dueDate?.toIso8601String(),
              'project': t.project,
              'labels': t.labels,
            },
          )
          .toList(),
      'notes': notes
          .map(
            (n) => <String, dynamic>{
              'id': n.id,
              'title': n.title,
              'content': n.content,
              'tags': n.tags,
              'folder': n.folder,
              'isPinned': n.isPinned,
              'isFavorite': n.isFavorite,
              'isArchived': n.isArchived,
            },
          )
          .toList(),
      'events': events
          .map(
            (e) => <String, dynamic>{
              'id': e.id,
              'title': e.title,
              'description': e.description,
              'startTime': e.startTime.toIso8601String(),
              'endTime': e.endTime.toIso8601String(),
              'location': e.location,
              'isAllDay': e.isAllDay,
            },
          )
          .toList(),
      'habits': habits
          .map(
            (h) => <String, dynamic>{
              'id': h.id,
              'name': h.name,
              'description': h.description,
              'frequency': h.frequency.name,
              'currentStreak': h.currentStreak,
              'xp': h.xp,
              'level': h.level,
            },
          )
          .toList(),
      'journal': journal
          .map(
            (j) => <String, dynamic>{
              'id': j.id,
              'title': j.title,
              'content': j.content,
              'mood': j.mood,
              'tags': j.tags,
            },
          )
          .toList(),
      'expenses': expenses
          .map(
            (e) => <String, dynamic>{
              'id': e.id,
              'description': e.description,
              'amount': e.amount,
              'category': e.category,
              'date': e.date.toIso8601String(),
              'isIncome': e.isIncome,
            },
          )
          .toList(),
      'goals': goals
          .map(
            (g) => <String, dynamic>{
              'id': g.id,
              'title': g.title,
              'description': g.description,
              'targetDate': g.targetDate.toIso8601String(),
              'progress': g.progress,
              'milestones': g.milestones,
            },
          )
          .toList(),
    };

    final Directory dir = await getApplicationDocumentsDirectory();
    final String stamp = now.toIso8601String().replaceAll(':', '-');
    final File file = File('${dir.path}/lifeos_backup_$stamp.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return file;
  }

  Future<void> shareBackup(String userId) async {
    final File file = await exportToFile(userId);
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path)],
        subject: 'LIFEOS AI backup',
        text: 'Your LIFEOS AI data export',
      ),
    );
  }
}
