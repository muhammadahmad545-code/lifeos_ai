import 'task.dart';

abstract class TaskRepository {
  Stream<List<Task>> watchTasks(String userId);

  Future<List<Task>> getTasks(String userId);

  Future<Task> createTask(String userId, Task task);

  Future<Task> updateTask(Task task);

  Future<void> deleteTask(String taskId);

  Future<void> markTaskComplete(String taskId, {required bool isCompleted});

  Future<List<Task>> searchTasks(String userId, String query);
}
