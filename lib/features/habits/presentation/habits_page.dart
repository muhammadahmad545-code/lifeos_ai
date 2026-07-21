import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/feature_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../domain/habit.dart';

class HabitsPage extends ConsumerStatefulWidget {
  const HabitsPage({super.key});

  @override
  ConsumerState<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends ConsumerState<HabitsPage> {
  String? get _userId => ref.read(authSessionProvider).valueOrNull?.id;

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $error'), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  bool _isDoneToday(Habit habit) {
    if (habit.lastCompletedAt == null) {
      return false;
    }
    final DateTime now = DateTime.now();
    final DateTime d = habit.lastCompletedAt!;
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Future<void> _complete(Habit habit) async {
    try {
      final Habit updated = await ref.read(habitRepositoryProvider).logHabitCompletion(habit.id, DateTime.now());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${habit.name}: streak ${updated.currentStreak}, XP ${updated.xp}')),
        );
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(Habit habit) async {
    try {
      await ref.read(habitRepositoryProvider).deleteHabit(habit.id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openForm({Habit? habit}) async {
    final String? userId = _userId;
    if (userId == null) {
      return;
    }
    final Habit? result = await showModalBottomSheet<Habit>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _HabitFormSheet(initial: habit),
    );
    if (result == null) {
      return;
    }
    try {
      if (habit == null) {
        await ref.read(habitRepositoryProvider).createHabit(userId, result);
      } else {
        await ref.read(habitRepositoryProvider).updateHabit(result);
      }
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Habit>> habitsAsync = ref.watch(watchHabitsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Habits')),
      body: habitsAsync.when(
        data: (List<Habit> habits) {
          if (habits.isEmpty) {
            return const EmptyStateView(title: 'No habits yet', message: 'Tap the + button to build your first habit.');
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: habits.length,
            itemBuilder: (BuildContext context, int index) {
              final Habit habit = habits[index];
              final bool doneToday = _isDoneToday(habit);
              final double xpIntoLevel = (habit.xp % 100) / 100;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          CircleAvatar(
                            backgroundColor: habit.color != null
                                ? Color(int.tryParse(habit.color!) ?? 0xFF6C63FF)
                                : Theme.of(context).colorScheme.primaryContainer,
                            child: Text('L${habit.level}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(habit.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                Text(
                                  '${habit.frequency.name} · ${habit.isActive ? "active" : "paused"}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (String value) {
                              switch (value) {
                                case 'edit':
                                  _openForm(habit: habit);
                                case 'delete':
                                  _delete(habit);
                              }
                            },
                            itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                              PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          _Metric(icon: Icons.local_fire_department, label: 'Streak', value: '${habit.currentStreak}'),
                          const SizedBox(width: 16),
                          _Metric(icon: Icons.emoji_events_outlined, label: 'Best', value: '${habit.longestStreak}'),
                          const SizedBox(width: 16),
                          _Metric(icon: Icons.bolt, label: 'XP', value: '${habit.xp}'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(value: xpIntoLevel, minHeight: 6),
                      ),
                      const SizedBox(height: 4),
                      Text('Level ${habit.level} · ${habit.xp % 100}/100 XP to next level', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: doneToday ? null : () => _complete(habit),
                          icon: Icon(doneToday ? Icons.check_circle : Icons.check_circle_outline),
                          label: Text(doneToday ? 'Completed today' : 'Complete today'),
                        ),
                      ),
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

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Text('$value ', style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _HabitFormSheet extends StatefulWidget {
  const _HabitFormSheet({this.initial});

  final Habit? initial;

  @override
  State<_HabitFormSheet> createState() => _HabitFormSheetState();
}

class _HabitFormSheetState extends State<_HabitFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late HabitFrequency _frequency;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final Habit? habit = widget.initial;
    _nameController = TextEditingController(text: habit?.name ?? '');
    _descriptionController = TextEditingController(text: habit?.description ?? '');
    _frequency = habit?.frequency ?? HabitFrequency.daily;
    _isActive = habit?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required.')));
      return;
    }
    final Habit result = (widget.initial ?? Habit(id: '', name: '', frequency: HabitFrequency.daily)).copyWith(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      frequency: _frequency,
      isActive: _isActive,
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
            Text(isEditing ? 'Edit habit' : 'New habit', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(controller: _nameController, autofocus: !isEditing, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description (optional)'), maxLines: 2),
            const SizedBox(height: 12),
            Text('Frequency', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: HabitFrequency.values
                  .map(
                    (HabitFrequency f) => ChoiceChip(
                      label: Text(f.name),
                      selected: _frequency == f,
                      onSelected: (_) => setState(() => _frequency = f),
                    ),
                  )
                  .toList(),
            ),
            if (isEditing) ...<Widget>[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _isActive,
                onChanged: (bool value) => setState(() => _isActive = value),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: Text(isEditing ? 'Save changes' : 'Create habit')),
          ],
        ),
      ),
    );
  }
}
