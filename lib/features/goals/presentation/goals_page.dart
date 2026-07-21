import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/feature_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../domain/goal.dart';

class GoalsPage extends ConsumerStatefulWidget {
  const GoalsPage({super.key});

  @override
  ConsumerState<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends ConsumerState<GoalsPage> {
  String? get _userId => ref.read(authSessionProvider).valueOrNull?.id;

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $error'), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  Future<void> _updateProgress(Goal goal, double progress) async {
    try {
      await ref.read(goalRepositoryProvider).updateProgress(goal.id, progress);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(Goal goal) async {
    try {
      await ref.read(goalRepositoryProvider).deleteGoal(goal.id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openForm({Goal? goal}) async {
    final String? userId = _userId;
    if (userId == null) {
      return;
    }
    final Goal? result = await showModalBottomSheet<Goal>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _GoalFormSheet(initial: goal),
    );
    if (result == null) {
      return;
    }
    try {
      if (goal == null) {
        await ref.read(goalRepositoryProvider).createGoal(userId, result);
      } else {
        await ref.read(goalRepositoryProvider).updateGoal(result);
      }
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Goal>> goalsAsync = ref.watch(watchGoalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      body: goalsAsync.when(
        data: (List<Goal> goals) {
          if (goals.isEmpty) {
            return const EmptyStateView(title: 'No goals yet', message: 'Tap the + button to set your first goal.');
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: goals.length,
            itemBuilder: (BuildContext context, int index) {
              final Goal goal = goals[index];
              final int daysLeft = goal.targetDate.difference(DateTime.now()).inDays;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              goal.title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    decoration: goal.isCompleted ? TextDecoration.lineThrough : null,
                                  ),
                            ),
                          ),
                          if (goal.isCompleted)
                            const Icon(Icons.emoji_events, color: Colors.amber)
                          else
                            Text(
                              daysLeft >= 0 ? '$daysLeft d left' : '${-daysLeft} d overdue',
                              style: TextStyle(color: daysLeft < 0 ? Colors.red : null, fontSize: 12),
                            ),
                          PopupMenuButton<String>(
                            onSelected: (String value) {
                              switch (value) {
                                case 'edit':
                                  _openForm(goal: goal);
                                case 'delete':
                                  _delete(goal);
                              }
                            },
                            itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                              PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ],
                      ),
                      if (goal.description != null && goal.description!.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(goal.description!, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: <Widget>[
                          if (goal.category != null) Chip(label: Text(goal.category!), visualDensity: VisualDensity.compact),
                          Chip(label: Text('Target: ${DateFormat.yMMMd().format(goal.targetDate)}'), visualDensity: VisualDensity.compact),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Slider(
                              value: goal.progress.clamp(0.0, 1.0),
                              onChanged: (double value) => _updateProgress(goal, value),
                              divisions: 20,
                              label: '${(goal.progress * 100).round()}%',
                            ),
                          ),
                          SizedBox(width: 48, child: Text('${(goal.progress * 100).round()}%', textAlign: TextAlign.end)),
                        ],
                      ),
                      if (goal.milestones.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text('Milestones', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 4),
                        ...goal.milestones.map(
                          (String m) => Row(
                            children: <Widget>[
                              const Icon(Icons.flag_outlined, size: 14),
                              const SizedBox(width: 6),
                              Expanded(child: Text(m, style: Theme.of(context).textTheme.bodySmall)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
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

class _GoalFormSheet extends StatefulWidget {
  const _GoalFormSheet({this.initial});

  final Goal? initial;

  @override
  State<_GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<_GoalFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _milestonesController;
  late DateTime _targetDate;
  late double _progress;

  @override
  void initState() {
    super.initState();
    final Goal? goal = widget.initial;
    _titleController = TextEditingController(text: goal?.title ?? '');
    _descriptionController = TextEditingController(text: goal?.description ?? '');
    _categoryController = TextEditingController(text: goal?.category ?? '');
    _milestonesController = TextEditingController(text: goal?.milestones.join(', ') ?? '');
    _targetDate = goal?.targetDate ?? DateTime.now().add(const Duration(days: 30));
    _progress = goal?.progress ?? 0;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _milestonesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required.')));
      return;
    }
    final List<String> milestones = _milestonesController.text
        .split(',')
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();
    final Goal result = (widget.initial ?? Goal(id: '', title: '', targetDate: _targetDate)).copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
      targetDate: _targetDate,
      milestones: milestones,
      progress: _progress,
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
            Text(isEditing ? 'Edit goal' : 'New goal', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(controller: _titleController, autofocus: !isEditing, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description (optional)'), maxLines: 2),
            const SizedBox(height: 12),
            TextField(controller: _categoryController, decoration: const InputDecoration(labelText: 'Category (optional)')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event_outlined),
              onPressed: _pickDate,
              label: Text('Target: ${DateFormat.yMMMd().format(_targetDate)}'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _milestonesController, decoration: const InputDecoration(labelText: 'Milestones (comma separated)')),
            const SizedBox(height: 12),
            Text('Progress: ${(_progress * 100).round()}%', style: Theme.of(context).textTheme.labelLarge),
            Slider(value: _progress, onChanged: (double v) => setState(() => _progress = v), divisions: 20),
            const SizedBox(height: 12),
            FilledButton(onPressed: _submit, child: Text(isEditing ? 'Save changes' : 'Create goal')),
          ],
        ),
      ),
    );
  }
}
