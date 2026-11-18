import 'package:basalt/basalt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/dates.dart';
import '../logic/rules.dart';
import '../providers.dart';
import 'common.dart';

String goalWhen(GoalRow g, DateTime now) {
  if (g.isCompleted) return 'Completed';
  final days = daysBetween(now, g.targetDate);
  if (days < 0) return '${-days} ${days == -1 ? 'day' : 'days'} past target';
  if (days == 0) return 'Target is today';
  return '$days ${days == 1 ? 'day' : 'days'} left · ${fmtDate(g.targetDate, now: now)}';
}

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider).list;
    final open = goals.where((g) => !g.isCompleted).toList();
    final done = goals.where((g) => g.isCompleted).toList();
    return SubPage(
      title: 'Goals',
      subtitle: goals.isEmpty ? null : '${open.length} active · ${done.length} completed',
      floating: AddButton(label: 'New goal', onPressed: () => push(context, const GoalEditor())),
      children: [
        if (goals.isEmpty)
          BEmptyState(
            icon: Icons.flag_outlined,
            title: 'No goals yet',
            message: 'Set a target date and break it into milestones. Progress follows the milestones you tick off.',
            actionLabel: 'New goal',
            onAction: () => push(context, const GoalEditor()),
          ),
        for (final g in open) GoalCard(goal: g),
        if (done.isNotEmpty) ...[
          const BSectionTitle('Completed'),
          for (final g in done) GoalCard(goal: g),
        ],
      ],
    );
  }
}

class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal});

  final GoalRow goal;

  @override
  Widget build(BuildContext context) {
    final p = context.basalt;
    final now = DateTime.now();
    final progress = goalProgress(milestones: goal.milestones, manual: goal.progress, completed: goal.isCompleted);
    final items = decodeMilestones(goal.milestones);
    final late = !goal.isCompleted && daysBetween(now, goal.targetDate) < 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: BCard(
        onTap: () => push(context, GoalEditor(goal: goal)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(goal.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: BasaltType.heading.copyWith(color: p.text)),
                ),
                Text('${(progress * 100).round()}%', style: BasaltType.bodyStrong.copyWith(color: goal.isCompleted ? p.success : p.accent)),
              ],
            ),
            const SizedBox(height: Gap.sm),
            BProgressBar(value: progress, color: goal.isCompleted ? p.success : null),
            const SizedBox(height: Gap.sm),
            Text(
              [
                goalWhen(goal, now),
                if (items.isNotEmpty) '${items.where((i) => i.done).length}/${items.length} milestones',
              ].join(' · '),
              style: BasaltType.caption.copyWith(color: late ? p.danger : p.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class GoalEditor extends ConsumerStatefulWidget {
  const GoalEditor({super.key, this.goal});

  final GoalRow? goal;

  @override
  ConsumerState<GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends ConsumerState<GoalEditor> {
  late final TextEditingController _title = TextEditingController(text: widget.goal?.title ?? '');
  late final TextEditingController _desc = TextEditingController(text: widget.goal?.description ?? '');
  final TextEditingController _newMilestone = TextEditingController();
  late DateTime _target = widget.goal?.targetDate ?? addMonths(DateTime.now(), 3);
  late double _manual = (widget.goal?.progress ?? 0.0).clamp(0.0, 1.0);
  late bool _completed = widget.goal?.isCompleted ?? false;
  late final List<CheckItem> _milestones = [...decodeMilestones(widget.goal?.milestones ?? '')];

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _newMilestone.dispose();
    super.dispose();
  }

  void _addMilestone() {
    final t = _newMilestone.text.trim();
    if (t.isEmpty) return;
    setState(() => _milestones.add(CheckItem(t)));
    _newMilestone.clear();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      BToast.show(context, 'Give the goal a title');
      return;
    }
    final desc = _desc.text.trim();
    final pending = _newMilestone.text.trim();
    if (pending.isNotEmpty) _milestones.add(CheckItem(pending));
    await ref.read(repoProvider).saveGoal(
          id: widget.goal?.id,
          title: title,
          description: desc.isEmpty ? null : desc,
          targetDate: dateOnly(_target),
          progress: _manual,
          milestones: encodeMilestones(_milestones),
          completed: _completed,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await bConfirm(context, title: 'Delete goal?', confirmLabel: 'Delete', danger: true);
    if (!ok) return;
    await ref.read(repoProvider).deleteGoal(widget.goal!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.basalt;
    final progress = goalProgress(milestones: encodeMilestones(_milestones), manual: _manual, completed: _completed);
    return EditorScaffold(
      title: widget.goal == null ? 'New goal' : 'Edit goal',
      onSave: _save,
      actions: [
        if (widget.goal != null) IconAction(icon: Icons.delete_outline_rounded, label: 'Delete goal', onPressed: _delete),
      ],
      children: [
        TextField(
          controller: _title,
          autofocus: widget.goal == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Goal', hintText: 'e.g. Run a 10K'),
        ),
        const SizedBox(height: Gap.md),
        TextField(
          controller: _desc,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Why it matters (optional)'),
        ),
        const FieldLabel('Target date'),
        PickerField(
          icon: Icons.flag_outlined,
          label: fmtDate(_target),
          onTap: () async {
            final d = await pickDate(context, _target);
            if (d != null) setState(() => _target = d);
          },
        ),
        const FieldLabel('Milestones'),
        BGroup(
          children: [
            for (var i = 0; i < _milestones.length; i++)
              BListRow(
                dense: true,
                leading: CheckCircle(
                  done: _milestones[i].done,
                  label: _milestones[i].done ? 'Reopen ${_milestones[i].text}' : 'Complete ${_milestones[i].text}',
                  onTap: () => setState(() => _milestones[i] = _milestones[i].copyWith(done: !_milestones[i].done)),
                ),
                title: _milestones[i].text,
                trailing: IconAction(
                  icon: Icons.close_rounded,
                  label: 'Remove ${_milestones[i].text}',
                  size: 18,
                  onPressed: () => setState(() => _milestones.removeAt(i)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.xs, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newMilestone,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _addMilestone(),
                      decoration: const InputDecoration(
                        hintText: 'Add a milestone',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                    ),
                  ),
                  IconAction(icon: Icons.add_rounded, label: 'Add milestone', onPressed: _addMilestone),
                ],
              ),
            ),
          ],
        ),
        const FieldLabel('Progress'),
        BCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _milestones.isEmpty ? 'Set progress by hand' : 'Follows your milestones',
                      style: BasaltType.label.copyWith(color: p.textMuted),
                    ),
                  ),
                  Text('${(progress * 100).round()}%', style: BasaltType.heading.copyWith(color: p.accent)),
                ],
              ),
              if (_milestones.isEmpty && !_completed)
                Slider(
                  value: _manual,
                  divisions: 20,
                  label: '${(_manual * 100).round()}%',
                  onChanged: (v) => setState(() => _manual = v),
                )
              else ...[
                const SizedBox(height: Gap.sm),
                BProgressBar(value: progress),
              ],
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        BGroup(
          children: [
            SwitchRow(
              icon: Icons.emoji_events_outlined,
              title: 'Completed',
              value: _completed,
              onChanged: (v) => setState(() => _completed = v),
            ),
          ],
        ),
      ],
    );
  }
}
