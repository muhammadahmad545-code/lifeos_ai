import 'task.dart';

class TaskTemplate {
  const TaskTemplate({
    required this.id,
    required this.name,
    required this.title,
    this.description,
    this.priority = TaskPriority.medium,
    this.project,
    this.labels = const <String>[],
    this.recurrence = TaskRecurrence.none,
    this.isBuiltIn = false,
  });

  final String id;
  final String name;
  final String title;
  final String? description;
  final TaskPriority priority;
  final String? project;
  final List<String> labels;
  final TaskRecurrence recurrence;
  final bool isBuiltIn;

  Task toTask() {
    return Task(
      id: '',
      title: title,
      description: description,
      isCompleted: false,
      priority: priority,
      project: project,
      labels: labels,
      recurrence: recurrence,
      isRecurring: recurrence != TaskRecurrence.none,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'title': title,
        'description': description,
        'priority': priority.index,
        'project': project,
        'labels': labels,
        'recurrence': recurrence.name,
        'isBuiltIn': isBuiltIn,
      };

  factory TaskTemplate.fromJson(Map<String, dynamic> json) {
    return TaskTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      priority: TaskPriorityX.fromIndex((json['priority'] as num?)?.toInt() ?? 1),
      project: json['project'] as String?,
      labels: ((json['labels'] as List<dynamic>?) ?? const <dynamic>[]).cast<String>(),
      recurrence: TaskRecurrenceX.fromStorage(json['recurrence'] as String?),
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }
}

class BuiltInTaskTemplates {
  static List<TaskTemplate> all = <TaskTemplate>[
    const TaskTemplate(
      id: 'tpl_daily_review',
      name: 'Daily review',
      title: 'Daily review',
      description: 'Review priorities, inbox, and calendar for today.',
      priority: TaskPriority.high,
      labels: <String>['review'],
      recurrence: TaskRecurrence.daily,
      isBuiltIn: true,
    ),
    const TaskTemplate(
      id: 'tpl_weekly_planning',
      name: 'Weekly planning',
      title: 'Plan the week',
      description: 'Set top 3 outcomes and schedule deep-work blocks.',
      priority: TaskPriority.high,
      labels: <String>['planning'],
      recurrence: TaskRecurrence.weekly,
      isBuiltIn: true,
    ),
    const TaskTemplate(
      id: 'tpl_standup',
      name: 'Meeting prep',
      title: 'Prepare for meeting',
      description: 'Agenda, notes, and action items.',
      priority: TaskPriority.medium,
      labels: <String>['meeting'],
      isBuiltIn: true,
    ),
    const TaskTemplate(
      id: 'tpl_workout',
      name: 'Workout',
      title: 'Workout session',
      description: 'Complete today\'s training plan.',
      priority: TaskPriority.medium,
      project: 'Health',
      labels: <String>['health'],
      recurrence: TaskRecurrence.daily,
      isBuiltIn: true,
    ),
  ];
}
