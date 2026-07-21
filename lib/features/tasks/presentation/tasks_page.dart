import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/feature_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../domain/task.dart';

enum _TaskFilter { all, active, done }

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  _TaskFilter _filter = _TaskFilter.all;

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
    final Task? result = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _TaskFormSheet(initial: task),
    );
    if (result == null) {
      return;
    }
    try {
      if (task == null) {
        await ref.read(taskRepositoryProvider).createTask(userId, result);
      } else {
        await ref.read(taskRepositoryProvider).updateTask(result);
      }
    } catch (error) {
      _showError(error);
    }
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
      appBar: AppBar(title: const Text('Tasks')),
      body: tasksAsync.when(
        data: (List<Task> tasks) {
          final List<Task> filtered = switch (_filter) {
            _TaskFilter.all => tasks,
            _TaskFilter.active => tasks.where((Task t) => !t.isCompleted).toList(),
            _TaskFilter.done => tasks.where((Task t) => t.isCompleted).toList(),
          };

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
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                        itemCount: filtered.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Task task = filtered[index];
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
                            onDismissed: (_) => _delete(task),
                            child: Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                onTap: () => _openForm(task: task),
                                leading: Checkbox(
                                  value: task.isCompleted,
                                  onChanged: (_) => _toggle(task),
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
                                        if (task.dueDate != null)
                                          _Tag(icon: Icons.schedule, label: DateFormat.MMMd().format(task.dueDate!)),
                                        if (task.project != null && task.project!.isNotEmpty)
                                          _Tag(icon: Icons.folder_outlined, label: task.project!),
                                        for (final String label in task.labels) _Tag(icon: Icons.label_outline, label: label),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(color: _priorityColor(task.priority), shape: BoxShape.circle),
                                ),
                                isThreeLine: task.description != null && task.description!.isNotEmpty,
                              ),
                            ),
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
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
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
  DateTime? _dueDate;

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

    final Task result = (widget.initial ?? Task(id: '', title: '', isCompleted: false)).copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      priority: _priority,
      project: _projectController.text.trim().isEmpty ? null : _projectController.text.trim(),
      labels: labels,
      dueDate: _dueDate,
      clearDueDate: _dueDate == null,
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
