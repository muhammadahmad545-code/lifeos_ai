import 'dart:async';

import 'package:basalt/basalt.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/dates.dart';
import '../logic/rules.dart';
import '../logic/tasks_view.dart';
import '../providers.dart';
import '../services/reminders.dart';
import 'common.dart';
import 'insights.dart';
import 'search.dart';

/// Subtitle for a task row: due, repeat, reminder and subtask progress.
String taskSubtitle(TaskRow t, List<TaskRow> subs, DateTime now) {
  final parts = <String>[if (t.parentId == null) taskCategory(t.project)];
  if (t.dueDate != null) parts.add(fmtDue(t.dueDate!, now: now));
  if (t.recurrence != 'none') parts.add('Repeats ${recurrenceLabel(t.recurrence).toLowerCase()}');
  if (t.reminderAt != null && !t.isCompleted && t.reminderAt!.isAfter(now)) parts.add('Reminder ${fmtTime(t.reminderAt!)}');
  if (subs.isNotEmpty) parts.add('${subs.where((s) => s.isCompleted).length}/${subs.length} subtasks');
  if (parts.length <= 1 && (t.description?.trim().isNotEmpty ?? false)) parts.add(t.description!.trim());
  return parts.join(' · ');
}

Future<void> toggleTask(BuildContext context, WidgetRef ref, TaskRow t) async {
  final repo = ref.read(repoProvider);
  final done = !t.isCompleted;
  await repo.setTaskDone(t.id, done);
  if (done && context.mounted) {
    // No undo action here: snackbars with actions never time out while accessibility
    // services run. Completed tasks can be reopened from the Done view.
    BToast.show(context, t.recurrence != 'none' ? 'Done. The next one is scheduled.' : 'Task completed');
  }
}

/// A snackbar with Undo that always goes away after a few seconds (snackbars with an action
/// otherwise stay up while accessibility services run).
void showUndoSnackBar(ScaffoldMessengerState messenger, String message, Future<void> Function() undo) {
  messenger.hideCurrentSnackBar();
  final controller = messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(label: 'Undo', onPressed: () => unawaited(undo())),
    ),
  );
  Timer(const Duration(seconds: 6), () {
    try {
      controller.close();
    } catch (_) {}
  });
}

/// Swipe right: complete (or reopen). Swipe left: delete. Both can be undone.
Future<void> swipeTask(BuildContext context, WidgetRef ref, TaskRow t, DismissDirection direction) async {
  final repo = ref.read(repoProvider);
  final messenger = ScaffoldMessenger.of(context);
  if (direction == DismissDirection.startToEnd) {
    final done = !t.isCompleted;
    await repo.setTaskDone(t.id, done);
    showUndoSnackBar(messenger, done ? 'Completed "${t.title}"' : 'Reopened "${t.title}"', () => repo.setTaskDone(t.id, !done));
  } else {
    final snapshot = await repo.deleteTaskForUndo(t.id);
    showUndoSnackBar(messenger, 'Deleted "${t.title}"', () => repo.restoreTasks(snapshot));
  }
}

/// One task in a list.
class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.task, this.subtasks = const [], this.swipe = true});

  final TaskRow task;
  final List<TaskRow> subtasks;
  final bool swipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.basalt;
    final now = DateTime.now();
    final overdue = !task.isCompleted && dueBucket(task.dueDate, now) == DueBucket.overdue;
    Widget? badge;
    if (overdue) {
      badge = BBadge('Overdue', color: p.danger);
    } else if (!task.isCompleted && task.priority >= 2) {
      badge = BBadge(priorityLabel(task.priority), color: task.priority == 3 ? p.danger : p.warning);
    }
    final row = BListRow(
      leading: CheckCircle(
        done: task.isCompleted,
        label: task.isCompleted ? 'Reopen ${task.title}' : 'Complete ${task.title}',
        onTap: () => toggleTask(context, ref, task),
      ),
      title: task.title,
      subtitle: taskSubtitle(task, subtasks, now),
      trailing: badge,
      onTap: () => push(context, TaskEditor(task: task)),
    );
    if (!swipe) return row;
    Widget side(Color color, IconData icon, String label, Alignment align) => Container(
          color: p.soft(color),
          alignment: align,
          padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: Gap.sm),
              Text(label, style: BasaltType.bodyStrong.copyWith(color: color)),
            ],
          ),
        );
    return Dismissible(
      key: ValueKey('swipe-${task.id}'),
      background: side(p.success, task.isCompleted ? Icons.undo_rounded : Icons.check_rounded, task.isCompleted ? 'Reopen' : 'Complete', Alignment.centerLeft),
      secondaryBackground: side(p.danger, Icons.delete_outline_rounded, 'Delete', Alignment.centerRight),
      // The change goes to the database and the list updates from it, so the row itself
      // springs back instead of being removed by the Dismissible.
      confirmDismiss: (direction) async {
        await swipeTask(context, ref, task, direction);
        return false;
      },
      child: row,
    );
  }
}

IconData categoryIconFor(String c) => switch (c) {
      'Personal' => Icons.person_outline_rounded,
      'Work' => Icons.work_outline_rounded,
      'Grocery' => Icons.local_grocery_store_outlined,
      'School' => Icons.school_outlined,
      _ => Icons.label_outline_rounded,
    };

enum _Filter { open, today, upcoming, done }

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  _Filter _filter = _Filter.open;
  String? _category;
  String _query = '';

  int _sort(TaskRow a, TaskRow b) {
    final ad = a.dueDate, bd = b.dueDate;
    if (ad != null && bd != null && ad != bd) return ad.compareTo(bd);
    if (ad == null && bd != null) return 1;
    if (ad != null && bd == null) return -1;
    final p = b.priority.compareTo(a.priority);
    if (p != 0) return p;
    return a.createdAt.compareTo(b.createdAt);
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(tasksProvider).list;
    final now = DateTime.now();
    final subs = <String, List<TaskRow>>{};
    for (final t in all) {
      if (t.parentId != null) subs.putIfAbsent(t.parentId!, () => []).add(t);
    }
    final counts = openCountsByCategory(all);
    final top = filterTasks(all, category: _category, query: _query);
    final open = top.where((t) => !t.isCompleted).toList()..sort(_sort);
    final done = top.where((t) => t.isCompleted).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    List<TaskRow> bucket(DueBucket b) => open.where((t) => dueBucket(t.dueDate, now) == b).toList();

    Widget group(String title, List<TaskRow> items) => items.isEmpty
        ? const SizedBox.shrink()
        : BGroup(
            title: '$title  ${items.length}',
            children: [for (final t in items) TaskTile(task: t, subtasks: subs[t.id] ?? const [])],
          );

    final sections = <Widget>[];
    switch (_filter) {
      case _Filter.open:
        sections.addAll([
          group('Overdue', bucket(DueBucket.overdue)),
          group('Today', bucket(DueBucket.today)),
          group('Upcoming', bucket(DueBucket.upcoming)),
          group('No date', bucket(DueBucket.someday)),
        ]);
      case _Filter.today:
        sections.addAll([group('Overdue', bucket(DueBucket.overdue)), group('Today', bucket(DueBucket.today))]);
      case _Filter.upcoming:
        final up = bucket(DueBucket.upcoming);
        final byDay = <String, List<TaskRow>>{};
        for (final t in up) {
          byDay.putIfAbsent(relativeDay(t.dueDate!, now: now), () => []).add(t);
        }
        for (final e in byDay.entries) {
          sections.add(group(e.key, e.value));
        }
      case _Filter.done:
        sections.add(group('Completed', done));
    }
    final empty = sections.every((w) => w is SizedBox);
    final filtered = _category != null || _query.trim().isNotEmpty;

    return BPage(
      title: 'Tasks',
      subtitle: open.isEmpty ? 'All clear' : '${open.length} open',
      actions: [
        IconAction(icon: Icons.insights_rounded, label: 'Insights', onPressed: () => push(context, const InsightsPage())),
        IconAction(icon: Icons.search_rounded, label: 'Search', onPressed: () => push(context, const SearchPage())),
      ],
      floating: AddButton(label: 'New task', onPressed: () => push(context, TaskEditor(initialCategory: _category))),
      children: [
        ChipWrap(
          children: [
            for (final c in [null, ...kTaskCategories])
              BChip(
                label: c == null ? 'All ${counts.values.fold<int>(0, (a, b) => a + b)}' : '$c ${counts[c]}',
                icon: c == null ? Icons.all_inbox_rounded : categoryIconFor(c),
                selected: _category == c,
                onTap: () => setState(() => _category = c),
              ),
          ],
        ),
        const SizedBox(height: Gap.sm),
        BSearchField(hint: 'Filter tasks', onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: Gap.md),
        ChipWrap(
          children: [
            BChip(label: 'Open', selected: _filter == _Filter.open, onTap: () => setState(() => _filter = _Filter.open)),
            BChip(label: 'Today', selected: _filter == _Filter.today, onTap: () => setState(() => _filter = _Filter.today)),
            BChip(
              label: 'Upcoming',
              selected: _filter == _Filter.upcoming,
              onTap: () => setState(() => _filter = _Filter.upcoming),
            ),
            BChip(label: 'Done', selected: _filter == _Filter.done, onTap: () => setState(() => _filter = _Filter.done)),
          ],
        ),
        if (empty)
          BEmptyState(
            icon: _filter == _Filter.done ? Icons.task_alt_rounded : Icons.checklist_rounded,
            title: filtered ? 'No matching tasks' : switch (_filter) {
              _Filter.done => 'Nothing completed yet',
              _Filter.today => 'Nothing due today',
              _Filter.upcoming => 'Nothing coming up',
              _Filter.open => 'No tasks yet',
            },
            message: _filter == _Filter.done ? null : 'Add a task with a due date, priority and reminder.',
            actionLabel: _filter == _Filter.done ? null : 'New task',
            onAction: () => push(context, const TaskEditor()),
          )
        else
          ...sections,
        const SizedBox(height: 72),
      ],
    );
  }
}

class TaskEditor extends ConsumerStatefulWidget {
  const TaskEditor({super.key, this.task, this.initialDue, this.initialCategory});

  final TaskRow? task;
  final DateTime? initialDue;
  final String? initialCategory;

  @override
  ConsumerState<TaskEditor> createState() => _TaskEditorState();
}

const List<(String, int)> _reminderOptions = [
  ('At due time', 0),
  ('10 min before', 10),
  ('1 hour before', 60),
  ('1 day before', 1440),
];

class _TaskEditorState extends ConsumerState<TaskEditor> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  final TextEditingController _newSub = TextEditingController();
  DateTime? _date;
  TimeOfDay? _time;
  int _priority = 1;
  String _recurrence = 'none';
  late String _category = taskCategory(widget.task?.project ?? widget.initialCategory);
  int? _reminder;
  DateTime? _customReminder;
  final List<String> _pendingSubs = [];
  bool _saving = false;

  bool get _editing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? '');
    _notes = TextEditingController(text: t?.description ?? '');
    final due = t?.dueDate ?? widget.initialDue;
    if (due != null) {
      _date = dateOnly(due);
      if (hasTime(due)) _time = TimeOfDay.fromDateTime(due);
    }
    if (t != null) {
      _priority = t.priority.clamp(0, 3);
      _recurrence = kRecurrences.contains(t.recurrence) ? t.recurrence : 'none';
      final r = t.reminderAt;
      final base = _reminderBase();
      if (r != null && base != null) {
        final diff = base.difference(r).inMinutes;
        if (_reminderOptions.any((o) => o.$2 == diff)) {
          _reminder = diff;
        } else {
          _customReminder = r;
        }
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _newSub.dispose();
    super.dispose();
  }

  /// Reminders are relative to the due time, or 9:00 on the due day when there is no time.
  DateTime? _reminderBase() {
    final d = _date;
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day, _time?.hour ?? 9, _time?.minute ?? 0);
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.text.trim();
    if (title.isEmpty) {
      BToast.show(context, 'Give the task a title');
      return;
    }
    setState(() => _saving = true);
    final d = _date;
    final due = d == null ? null : DateTime(d.year, d.month, d.day, _time?.hour ?? 0, _time?.minute ?? 0);
    DateTime? reminderAt;
    final base = _reminderBase();
    if (base != null) {
      if (_reminder != null) {
        reminderAt = base.subtract(Duration(minutes: _reminder!));
      } else {
        reminderAt = _customReminder;
      }
    }
    String? warning;
    if (reminderAt != null) {
      if (!reminderAt.isAfter(DateTime.now())) {
        warning = 'That reminder time has already passed';
      } else if (!await Reminders.instance.ensurePermission()) {
        warning = 'Notifications are off for Plania, so the reminder cannot appear';
      }
    }
    final repo = ref.read(repoProvider);
    final notes = _notes.text.trim();
    final id = await repo.saveTask(
      TasksCompanion(
        title: Value(title),
        description: Value(notes.isEmpty ? null : notes),
        dueDate: Value(due),
        priority: Value(_priority),
        project: Value(_projectValue()),
        recurrence: Value(_recurrence),
        isRecurring: Value(_recurrence != 'none'),
        reminderAt: Value(reminderAt),
      ),
      id: widget.task?.id,
    );
    for (final s in _pendingSubs) {
      await repo.addSubtask(id, s);
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (warning != null) messenger.showSnackBar(SnackBar(content: Text(warning)));
  }

  /// General is stored as null, but a free-form 1.x project name is kept while the category
  /// stays General.
  String? _projectValue() {
    if (_category != kDefaultCategory) return _category;
    final old = widget.task?.project;
    return old != null && !kTaskCategories.contains(old) ? old : null;
  }

  Future<void> _delete() async {
    final t = widget.task;
    if (t == null) return;
    final ok = await bConfirm(context, title: 'Delete task?', message: '"${t.title}" and its subtasks will be deleted.', confirmLabel: 'Delete', danger: true);
    if (!ok) return;
    await ref.read(repoProvider).deleteTask(t.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addSub() async {
    final text = _newSub.text.trim();
    if (text.isEmpty) return;
    _newSub.clear();
    if (_editing) {
      await ref.read(repoProvider).addSubtask(widget.task!.id, text);
    } else {
      setState(() => _pendingSubs.add(text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.basalt;
    final subs = _editing
        ? (ref.watch(tasksProvider).list.where((t) => t.parentId == widget.task!.id).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)))
        : const <TaskRow>[];
    final live = _editing ? ref.watch(tasksProvider).list.where((t) => t.id == widget.task!.id).firstOrNull : null;

    return EditorScaffold(
      title: _editing ? 'Edit task' : 'New task',
      onSave: _saving ? null : _save,
      actions: [
        if (_editing) IconAction(icon: Icons.delete_outline_rounded, label: 'Delete task', onPressed: _delete),
      ],
      children: [
        TextField(
          controller: _title,
          autofocus: !_editing,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: Gap.md),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Notes (optional)'),
        ),
        const FieldLabel('Category'),
        ChipWrap(
          children: [
            for (final c in kTaskCategories)
              BChip(label: c, icon: categoryIconFor(c), selected: _category == c, onTap: () => setState(() => _category = c)),
          ],
        ),
        const FieldLabel('Due'),
        Row(
          children: [
            Expanded(
              child: PickerField(
                icon: Icons.event_rounded,
                label: _date == null ? 'No date' : relativeDay(_date!),
                onTap: () async {
                  final d = await pickDate(context, _date);
                  if (d != null) setState(() => _date = d);
                },
                onClear: _date == null
                    ? null
                    : () => setState(() {
                          _date = null;
                          _time = null;
                          _reminder = null;
                          _customReminder = null;
                        }),
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: PickerField(
                icon: Icons.schedule_rounded,
                label: _time == null ? 'Any time' : _time!.format(context),
                onTap: () async {
                  final t = await pickTime(context, _time);
                  if (t != null) {
                    setState(() {
                      _time = t;
                      _date ??= dateOnly(DateTime.now());
                    });
                  }
                },
                onClear: _time == null ? null : () => setState(() => _time = null),
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.sm),
        ChipWrap(
          children: [
            for (final (label, offset) in [('Today', 0), ('Tomorrow', 1), ('Next week', 7)])
              BChip(
                label: label,
                selected: _date != null && daysBetween(DateTime.now(), _date!) == offset,
                onTap: () => setState(() => _date = addDays(dateOnly(DateTime.now()), offset)),
              ),
          ],
        ),
        const FieldLabel('Priority'),
        ChipWrap(
          children: [
            for (var i = 0; i < kPriorityLabels.length; i++)
              BChip(
                label: kPriorityLabels[i],
                selected: _priority == i,
                color: i == 3 ? p.danger : (i == 2 ? p.warning : null),
                onTap: () => setState(() => _priority = i),
              ),
          ],
        ),
        const FieldLabel('Repeat'),
        ChipWrap(
          children: [
            for (final r in kRecurrences)
              BChip(label: recurrenceLabel(r), selected: _recurrence == r, onTap: () => setState(() => _recurrence = r)),
          ],
        ),
        const FieldLabel('Reminder'),
        if (_date == null)
          Text('Set a due date to add a reminder.', style: BasaltType.caption.copyWith(color: p.textMuted))
        else
          ChipWrap(
            children: [
              BChip(
                label: 'None',
                selected: _reminder == null && _customReminder == null,
                onTap: () => setState(() {
                  _reminder = null;
                  _customReminder = null;
                }),
              ),
              for (final (label, minutes) in _reminderOptions)
                BChip(
                  label: label,
                  icon: Icons.notifications_none_rounded,
                  selected: _reminder == minutes,
                  onTap: () => setState(() {
                    _reminder = minutes;
                    _customReminder = null;
                  }),
                ),
              if (_customReminder != null)
                BChip(label: '${fmtDate(_customReminder!)} ${fmtTime(_customReminder!)}', selected: true, onTap: () {}),
            ],
          ),
        if (_date != null && _time == null && (_reminder != null || _customReminder != null))
          Padding(
            padding: const EdgeInsets.only(top: Gap.sm),
            child: Text('No time set, so the reminder is based on 9:00 AM.', style: BasaltType.caption.copyWith(color: p.textMuted)),
          ),
        const FieldLabel('Subtasks'),
        BGroup(
          children: [
            if (_editing)
              for (final s in subs)
                BListRow(
                  dense: true,
                  leading: CheckCircle(
                    done: s.isCompleted,
                    label: s.isCompleted ? 'Reopen ${s.title}' : 'Complete ${s.title}',
                    onTap: () => ref.read(repoProvider).setTaskDone(s.id, !s.isCompleted),
                  ),
                  title: s.title,
                  trailing: IconAction(
                    icon: Icons.close_rounded,
                    label: 'Remove ${s.title}',
                    size: 18,
                    onPressed: () => ref.read(repoProvider).deleteTask(s.id),
                  ),
                )
            else
              for (var i = 0; i < _pendingSubs.length; i++)
                BListRow(
                  dense: true,
                  icon: Icons.subdirectory_arrow_right_rounded,
                  title: _pendingSubs[i],
                  trailing: IconAction(
                    icon: Icons.close_rounded,
                    label: 'Remove ${_pendingSubs[i]}',
                    size: 18,
                    onPressed: () => setState(() => _pendingSubs.removeAt(i)),
                  ),
                ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.xs, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newSub,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _addSub(),
                      decoration: const InputDecoration(
                        hintText: 'Add a subtask',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                    ),
                  ),
                  IconAction(icon: Icons.add_rounded, label: 'Add subtask', onPressed: _addSub),
                ],
              ),
            ),
          ],
        ),
        if (_editing && live != null) ...[
          const SizedBox(height: Gap.xl),
          BButton(
            label: live.isCompleted ? 'Mark as not done' : 'Mark as done',
            icon: live.isCompleted ? Icons.undo_rounded : Icons.check_rounded,
            variant: BButtonVariant.secondary,
            expand: true,
            onPressed: () async {
              await ref.read(repoProvider).setTaskDone(live.id, !live.isCompleted);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }
}
