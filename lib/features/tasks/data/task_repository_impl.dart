import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/list_codec.dart';
import '../domain/task.dart';
import '../domain/task_repository.dart';

class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Task>> watchTasks(String userId) {
    final query = (_db.select(_db.tasks)
          ..where((Tasks tbl) => tbl.userId.equals(userId))
          ..orderBy(<OrderingTerm Function(Tasks)>[
            (Tasks tbl) => OrderingTerm(expression: tbl.isCompleted),
            (Tasks tbl) => OrderingTerm.desc(tbl.priority),
            (Tasks tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch();
    return query.map((List<TaskRow> rows) => rows.map(_map).toList());
  }

  @override
  Future<List<Task>> getTasks(String userId) async {
    final List<TaskRow> rows = await (_db.select(_db.tasks)
          ..where((Tasks tbl) => tbl.userId.equals(userId))
          ..orderBy(<OrderingTerm Function(Tasks)>[
            (Tasks tbl) => OrderingTerm(expression: tbl.isCompleted),
            (Tasks tbl) => OrderingTerm.desc(tbl.priority),
          ]))
        .get();
    return rows.map(_map).toList();
  }

  @override
  Future<Task> createTask(String userId, Task task) async {
    final DateTime now = DateTime.now();
    final String id = task.id.isEmpty ? IdGenerator.next() : task.id;
    await _db.into(_db.tasks).insert(
          TasksCompanion.insert(
            id: id,
            userId: userId,
            title: task.title,
            description: Value<String?>(task.description),
            isCompleted: Value<bool>(task.isCompleted),
            dueDate: Value<DateTime?>(task.dueDate),
            priority: Value<int>(task.priority.index),
            project: Value<String?>(task.project),
            labels: Value<String>(ListCodec.encode(task.labels)),
            parentId: Value<String?>(task.parentId),
            isRecurring: Value<bool>(task.isRecurring),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final TaskRow row = await (_db.select(_db.tasks)..where((Tasks tbl) => tbl.id.equals(id))).getSingle();
    return _map(row);
  }

  @override
  Future<Task> updateTask(Task task) async {
    await (_db.update(_db.tasks)..where((Tasks tbl) => tbl.id.equals(task.id))).write(
          TasksCompanion(
            title: Value<String>(task.title),
            description: Value<String?>(task.description),
            isCompleted: Value<bool>(task.isCompleted),
            dueDate: Value<DateTime?>(task.dueDate),
            priority: Value<int>(task.priority.index),
            project: Value<String?>(task.project),
            labels: Value<String>(ListCodec.encode(task.labels)),
            parentId: Value<String?>(task.parentId),
            isRecurring: Value<bool>(task.isRecurring),
            updatedAt: Value<DateTime>(DateTime.now()),
          ),
        );
    final TaskRow row = await (_db.select(_db.tasks)..where((Tasks tbl) => tbl.id.equals(task.id))).getSingle();
    return _map(row);
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await (_db.delete(_db.tasks)..where((Tasks tbl) => tbl.id.equals(taskId))).go();
  }

  @override
  Future<void> markTaskComplete(String taskId, {required bool isCompleted}) async {
    await (_db.update(_db.tasks)..where((Tasks tbl) => tbl.id.equals(taskId))).write(
          TasksCompanion(
            isCompleted: Value<bool>(isCompleted),
            updatedAt: Value<DateTime>(DateTime.now()),
          ),
        );
  }

  @override
  Future<List<Task>> searchTasks(String userId, String query) async {
    final String q = query.trim().toLowerCase();
    final List<Task> all = await getTasks(userId);
    if (q.isEmpty) {
      return all;
    }
    return all
        .where(
          (Task task) =>
              task.title.toLowerCase().contains(q) ||
              (task.description?.toLowerCase().contains(q) ?? false) ||
              task.labels.any((String label) => label.toLowerCase().contains(q)),
        )
        .toList();
  }

  Task _map(TaskRow row) {
    return Task(
      id: row.id,
      title: row.title,
      description: row.description,
      isCompleted: row.isCompleted,
      dueDate: row.dueDate,
      priority: TaskPriorityX.fromIndex(row.priority),
      project: row.project,
      labels: ListCodec.decode(row.labels),
      parentId: row.parentId,
      isRecurring: row.isRecurring,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
