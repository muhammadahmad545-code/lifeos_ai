class Task {
  const Task({
    required this.id,
    required this.title,
    this.description,
    required this.isCompleted,
    this.dueDate,
    this.priority = TaskPriority.medium,
    this.project,
    this.labels = const <String>[],
    this.parentId,
    this.isRecurring = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final bool isCompleted;
  final DateTime? dueDate;
  final TaskPriority priority;
  final String? project;
  final List<String> labels;
  final String? parentId;
  final bool isRecurring;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Task copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? dueDate,
    TaskPriority? priority,
    String? project,
    List<String>? labels,
    String? parentId,
    bool? isRecurring,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearDueDate = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      project: project ?? this.project,
      labels: labels ?? this.labels,
      parentId: parentId ?? this.parentId,
      isRecurring: isRecurring ?? this.isRecurring,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum TaskPriority { low, medium, high, urgent }

extension TaskPriorityX on TaskPriority {
  int get sortValue => index;

  String get label => switch (this) {
        TaskPriority.low => 'Low',
        TaskPriority.medium => 'Medium',
        TaskPriority.high => 'High',
        TaskPriority.urgent => 'Urgent',
      };

  static TaskPriority fromIndex(int value) {
    if (value < 0 || value >= TaskPriority.values.length) {
      return TaskPriority.medium;
    }
    return TaskPriority.values[value];
  }
}
