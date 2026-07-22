import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/feature_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../domain/task.dart';
import '../domain/task_template.dart';

enum _TaskFilter { all, active, done }

enum _TaskView { list, board }

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  _TaskFilter _filter = _TaskFilter.all;
  _TaskView _view = _TaskView.list;

  String? get _userId => ref.read(authSessionProvider).valueOrNull?.id;

  Future<void> _toggle(Task task) async {
    try {
      await ref.read(taskRepositoryProvider).markTaskComplete(task.id, isCompleted: !task.isCompleted);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(Task task) async {
    try {
      await ref.read(taskRepositoryProvider).deleteTask(task.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted "${task.title}"')));
      }
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $error'), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  Future<void> _openForm({Task? task}) async {
    final String? userId = _userId;
    if (userId == null) {
      return;
    }
    final bool isNew = task == null || task.id.isEmpty;
    final Task? result = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _TaskFormSheet(initial: task),
    );
    if (result == null) {
      return;
    }
    try {
      final Task toSave = result.copyWith(
        parentId: result.parentId ?? task?.parentId,
      );
      final Task saved = isNew
          ? await ref.read(taskRepositoryProvider).createTask(userId, toSave)
          : await ref.read(taskRepositoryProvider).updateTask(toSave.copyWith(id: task.id));
      final DateTime? reminder = saved.reminderAt ?? saved.dueDate;
      if (reminder != null && ref.read(settingsServiceProvider).notificationsEnabled) {
        await ref.read(localNotificationServiceProvider).scheduleReminder(
              id: saved.id.hashCode,
              title: 'Task reminder',
              body: saved.title,
              when: reminder,
            );
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _createFromTemplate(TaskTemplate template) async {
    await _openForm(task: template.toTask());
  }

  Future<void> _saveAsTemplate(Task task) async {
    final TextEditingController nameController = TextEditingController(text: task.title);
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Save as template'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Template name'),
          autofocus: true,
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) {
      return;
    }
    try {
      await ref.read(taskTemplateStoreProvider).saveFromTask(task, name: name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Template "$name" saved')));
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _showTemplates() async {
    final List<TaskTemplate> templates = ref.read(taskTemplateStoreProvider).getAll();
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            const ListTile(title: Text('Task templates'), subtitle: Text('Create a task from a template')),
            ...templates.map(
              (TaskTemplate template) => ListTile(
                leading: Icon(template.isBuiltIn ? Icons.auto_awesome : Icons.bookmark_outline),
                title: Text(template.name),
                subtitle: Text('${template.priority.label}${template.recurrence != TaskRecurrence.none ? ' · ${template.recurrence.label}' : ''}'),
                trailing: template.isBuiltIn
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await ref.read(taskTemplateStoreProvider).delete(template.id);
                          if (context.mounted) {
                            Navigator.pop(context);
                            _showTemplates();
                          }
                        },
                      ),
                onTap: () {
                  Navigator.pop(context);
                  _createFromTemplate(template);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.add_task),
              title: const Text('New task'),
              onTap: () {
                Navigator.pop(context);
                _openForm();
              },
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_customize_outlined),
              title: const Text('From template'),
              onTap: () {
                Navigator.pop(context);
                _showTemplates();
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.blueGrey;
      case TaskPriority.medium:
        return Colors.blue;
      case TaskPriority.high:
        return Colors.orange;
      case TaskPriority.urgent:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Task>> tasksAsync = ref.watch(watchTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Templates',
            onPressed: _showTemplates,
            icon: const Icon(Icons.dashboard_customize_outlined),
          ),
          IconButton(
            tooltip: _view == _TaskView.list ? 'Board view' : 'List view',
            onPressed: () => setState(() {
              _view = _view == _TaskView.list ? _TaskView.board : _TaskView.list;
            }),
            icon: Icon(_view == _TaskView.list ? Icons.view_kanban_outlined : Icons.view_list_rounded),
          ),
        ],
      ),
      body: tasksAsync.when(
        data: (List<Task> tasks) {
          final List<Task> filtered = switch (_filter) {
            _TaskFilter.all => tasks,
            _TaskFilter.active => tasks.where((Task t) => !t.isCompleted).toList(),
            _TaskFilter.done => tasks.where((Task t) => t.isCompleted).toList(),
          };
          final List<Task> roots = filtered.where((Task t) => t.parentId == null).toList();
          List<Task> childrenOf(String id) => filtered.where((Task t) => t.parentId == id).toList();

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: <Widget>[
                    _FilterChip(
                      label: 'All (${tasks.length})',
                      selected: _filter == _TaskFilter.all,
                      onTap: () => setState(() => _filter = _TaskFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Active (${tasks.where((t) => !t.isCompleted).length})',
                      selected: _filter == _TaskFilter.active,
                      onTap: () => setState(() => _filter = _TaskFilter.active),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Done (${tasks.where((t) => t.isCompleted).length})',
                      selected: _filter == _TaskFilter.done,
                      onTap: () => setState(() => _filter = _TaskFilter.done),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyStateView(
                        title: 'No tasks here',
                        message: 'Tap the + button to add your first task.',
                      )
                    : _view == _TaskView.board
                        ? _KanbanBoard(
                            tasks: filtered,
                            priorityColor: _priorityColor,
                            onToggle: _toggle,
                            onOpen: (Task task) => _openForm(task: task),
                          )
                        : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                        itemCount: roots.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Task task = roots[index];
                          final List<Task> children = childrenOf(task.id);
                          return Column(
                            children: <Widget>[
                              _TaskListTile(
                                task: task,
                                priorityColor: _priorityColor(task.priority),
                                onToggle: () => _toggle(task),
                                onOpen: () => _openForm(task: task),
                                onDelete: () => _delete(task),
                                onSaveTemplate: () => _saveAsTemplate(task),
                                onAddSubtask: () => _openForm(
                                  task: Task(
                                    id: '',
                                    title: '',
                                    isCompleted: false,
                                    parentId: task.id,
                                    project: task.project,
                                    priority: task.priority,
                                  ),
                                ),
                              ),
                              ...children.map(
                                (Task child) => Padding(
                                  padding: const EdgeInsets.only(left: 28),
                                  child: _TaskListTile(
                                    task: child,
                                    priorityColor: _priorityColor(child.priority),
                                    onToggle: () => _toggle(child),
                                    onOpen: () => _openForm(task: child),
                                    onDelete: () => _delete(child),
                                    onSaveTemplate: () => _saveAsTemplate(child),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TaskListTile extends StatelessWidget {
  const _TaskListTile({
    required this.task,
    required this.priorityColor,
    required this.onToggle,
    required this.onOpen,
    required this.onDelete,
    this.onAddSubtask,
    this.onSaveTemplate,
  });

  final Task task;
  final Color priorityColor;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback? onAddSubtask;
  final VoidCallback? onSaveTemplate;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey<String>(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: const Text('Delete task?'),
                content: Text('"${task.title}" will be permanently removed.'),
                actions: <Widget>[
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          onTap: onOpen,
          leading: Checkbox(
            value: task.isCompleted,
            onChanged: (_) => onToggle(),
            shape: const CircleBorder(),
          ),
          title: Text(
            task.title,
            style: TextStyle(
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              color: task.isCompleted ? Theme.of(context).disabledColor : null,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (task.description != null && task.description!.isNotEmpty)
                Text(task.description!, maxLines: 1, overflow: TextOverflow.ellipsis),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: <Widget>[
                  if (task.dueDate != null) _Tag(icon: Icons.schedule, label: DateFormat.MMMd().format(task.dueDate!)),
                  if (task.recurrence != TaskRecurrence.none) _Tag(icon: Icons.repeat, label: task.recurrence.label),
                  if (task.project != null && task.project!.isNotEmpty) _Tag(icon: Icons.folder_outlined, label: task.project!),
                  for (final String label in task.labels) _Tag(icon: Icons.label_outline, label: label),
                ],
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (onAddSubtask != null)
                IconButton(
                  tooltip: 'Add subtask',
                  icon: const Icon(Icons.subdirectory_arrow_right),
                  onPressed: onAddSubtask,
                ),
              PopupMenuButton<String>(
                onSelected: (String value) {
                  if (value == 'template') {
                    onSaveTemplate?.call();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  if (onSaveTemplate != null)
                    const PopupMenuItem<String>(value: 'template', child: Text('Save as template')),
                  const PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                ],
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle),
              ),
            ],
          ),
          isThreeLine: task.description != null && task.description!.isNotEmpty,
        ),
      ),
    );
  }
}

class _KanbanBoard extends StatelessWidget {
  const _KanbanBoard({
    required this.tasks,
    required this.priorityColor,
    required this.onToggle,
    required this.onOpen,
  });

  final List<Task> tasks;
  final Color Function(TaskPriority) priorityColor;
  final Future<void> Function(Task) onToggle;
  final void Function(Task) onOpen;

  @override
  Widget build(BuildContext context) {
    final List<Task> todo = tasks
        .where((Task t) => !t.isCompleted && (t.priority == TaskPriority.low || t.priority == TaskPriority.medium))
        .toList();
    final List<Task> doing = tasks
        .where((Task t) => !t.isCompleted && (t.priority == TaskPriority.high || t.priority == TaskPriority.urgent))
        .toList();
    final List<Task> done = tasks.where((Task t) => t.isCompleted).toList();

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
      children: <Widget>[
        _KanbanColumn(title: 'To Do', tasks: todo, color: Colors.blueGrey, priorityColor: priorityColor, onToggle: onToggle, onOpen: onOpen),
        _KanbanColumn(title: 'Doing', tasks: doing, color: Colors.orange, priorityColor: priorityColor, onToggle: onToggle, onOpen: onOpen),
        _KanbanColumn(title: 'Done', tasks: done, color: Colors.green, priorityColor: priorityColor, onToggle: onToggle, onOpen: onOpen),
      ],
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.title,
    required this.tasks,
    required this.color,
    required this.priorityColor,
    required this.onToggle,
    required this.onOpen,
  });

  final String title;
  final List<Task> tasks;
  final Color color;
  final Color Function(TaskPriority) priorityColor;
  final Future<void> Function(Task) onToggle;
  final void Function(Task) onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('$title (${tasks.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (BuildContext context, int index) {
                final Task task = tasks[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    onTap: () => onOpen(task),
                    title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(task.priority.label),
                    trailing: IconButton(
                      icon: Icon(task.isCompleted ? Icons.check_circle : Icons.circle_outlined),
                      color: priorityColor(task.priority),
                      onPressed: () => onToggle(task),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _TaskFormSheet extends StatefulWidget {
  const _TaskFormSheet({this.initial});

  final Task? initial;

  @override
  State<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<_TaskFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _projectController;
  late final TextEditingController _labelsController;
  late TaskPriority _priority;
  late TaskRecurrence _recurrence;
  DateTime? _dueDate;
  bool _remindMe = false;

  @override
  void initState() {
    super.initState();
    final Task? task = widget.initial;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(text: task?.description ?? '');
    _projectController = TextEditingController(text: task?.project ?? '');
    _labelsController = TextEditingController(text: task?.labels.join(', ') ?? '');
    _priority = task?.priority ?? TaskPriority.medium;
    _dueDate = task?.dueDate;
    _recurrence = task?.recurrence ?? TaskRecurrence.none;
    _remindMe = task?.reminderAt != null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _projectController.dispose();
    _labelsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required.')));
      return;
    }
    final List<String> labels = _labelsController.text
        .split(',')
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();

    final DateTime? reminderAt = _remindMe && _dueDate != null
        ? _dueDate!.subtract(const Duration(hours: 1))
        : null;
    final Task result = (widget.initial ?? Task(id: '', title: '', isCompleted: false)).copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      priority: _priority,
      project: _projectController.text.trim().isEmpty ? null : _projectController.text.trim(),
      labels: labels,
      dueDate: _dueDate,
      clearDueDate: _dueDate == null,
      recurrence: _recurrence,
      isRecurring: _recurrence != TaskRecurrence.none,
      reminderAt: reminderAt,
      clearReminder: reminderAt == null,
      parentId: widget.initial?.parentId,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.initial != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(isEditing ? 'Edit task' : 'New task', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: !isEditing,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Text('Priority', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: TaskPriority.values
                  .map(
                    (TaskPriority p) => ChoiceChip(
                      label: Text(p.label),
                      selected: _priority == p,
                      onSelected: (_) => setState(() => _priority = p),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined),
                    onPressed: _pickDate,
                    label: Text(_dueDate == null ? 'Set due date' : DateFormat.yMMMd().format(_dueDate!)),
                  ),
                ),
                if (_dueDate != null)
                  IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _dueDate = null)),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<TaskRecurrence>(
              initialValue: _recurrence,
              decoration: const InputDecoration(labelText: 'Repeat'),
              items: TaskRecurrence.values
                  .map((TaskRecurrence value) => DropdownMenuItem<TaskRecurrence>(value: value, child: Text(value.label)))
                  .toList(),
              onChanged: (TaskRecurrence? value) {
                if (value != null) {
                  setState(() => _recurrence = value);
                }
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Remind me 1 hour before due'),
              value: _remindMe,
              onChanged: _dueDate == null ? null : (bool value) => setState(() => _remindMe = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _projectController,
              decoration: const InputDecoration(labelText: 'Project (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _labelsController,
              decoration: const InputDecoration(labelText: 'Labels (comma separated)'),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: Text(isEditing ? 'Save changes' : 'Create task')),
          ],
        ),
      ),
    );
  }
}
