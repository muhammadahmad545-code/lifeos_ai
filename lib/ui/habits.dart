import 'package:basalt/basalt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/dates.dart';
import '../logic/rules.dart';
import '../providers.dart';
import 'common.dart';

Future<void> toggleHabitToday(WidgetRef ref, HabitRow h, bool doneNow) =>
    ref.read(repoProvider).setHabitDone(h.id, DateTime.now(), !doneNow);

class HabitsPage extends ConsumerWidget {
  const HabitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider).list;
    final days = ref.watch(habitDaysProvider);
    final now = DateTime.now();
    final todayKey = dayKey(now);
    final active = habits.where((h) => h.isActive).toList();
    final paused = habits.where((h) => !h.isActive).toList();
    final doneToday = active.where((h) => days[h.id]?.contains(todayKey) ?? false).length;
    final best = habits.fold<int>(0, (m, h) {
      final b = bestStreak(days[h.id] ?? const {});
      return b > m ? b : m;
    });

    return SubPage(
      title: 'Habits',
      subtitle: active.isEmpty ? null : '$doneToday of ${active.length} done today',
      floating: AddButton(label: 'New habit', onPressed: () => editHabit(context, ref, null)),
      children: [
        if (habits.isEmpty)
          BEmptyState(
            icon: Icons.local_fire_department_outlined,
            title: 'No habits yet',
            message: 'Track something you want to do every day and build a streak.',
            actionLabel: 'New habit',
            onAction: () => editHabit(context, ref, null),
          )
        else ...[
          Row(
            children: [
              Expanded(child: BStatTile(label: 'Done today', value: '$doneToday/${active.length}', icon: Icons.check_circle_outline_rounded)),
              const SizedBox(width: Gap.md),
              Expanded(child: BStatTile(label: 'Best streak', value: '$best ${best == 1 ? 'day' : 'days'}', icon: Icons.local_fire_department_outlined)),
            ],
          ),
          const SizedBox(height: Gap.md),
          for (final h in active) HabitCard(habit: h, days: days[h.id] ?? const {}),
          if (paused.isNotEmpty) ...[
            const BSectionTitle('Paused'),
            for (final h in paused) HabitCard(habit: h, days: days[h.id] ?? const {}),
          ],
        ],
      ],
    );
  }
}

class HabitCard extends ConsumerWidget {
  const HabitCard({super.key, required this.habit, required this.days});

  final HabitRow habit;
  final Set<String> days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.basalt;
    final now = DateTime.now();
    final today = dateOnly(now);
    final done = days.contains(dayKey(today));
    final cur = currentStreak(days, now);
    final best = bestStreak(days);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: BCard(
        onTap: () => editHabit(context, ref, habit),
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.sm, Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(habit.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: BasaltType.heading.copyWith(color: p.text)),
                      const SizedBox(height: 2),
                      Text(
                        cur == 0 ? 'No streak yet · best $best' : '$cur-day streak · best $best',
                        style: BasaltType.caption.copyWith(color: cur > 0 ? p.accent : p.textMuted),
                      ),
                    ],
                  ),
                ),
                if (habit.isActive)
                  CheckCircle(
                    done: done,
                    label: done ? 'Undo ${habit.name} today' : 'Check off ${habit.name}',
                    onTap: () => toggleHabitToday(ref, habit, done),
                  ),
              ],
            ),
            const SizedBox(height: Gap.md),
            // Last 7 days. Tap a day to fix a missed check-in.
            Row(
              children: [
                for (var i = 6; i >= 0; i--)
                  Expanded(
                    child: _DayDot(
                      day: addDays(today, -i),
                      done: days.contains(dayKey(addDays(today, -i))),
                      onTap: () => ref.read(repoProvider).setHabitDone(
                            habit.id,
                            addDays(today, -i),
                            !days.contains(dayKey(addDays(today, -i))),
                          ),
                    ),
                  ),
                const SizedBox(width: Gap.sm),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.day, required this.done, required this.onTap});

  final DateTime day;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.basalt;
    return Semantics(
      button: true,
      checked: done,
      label: '${DateFormat('EEEE').format(day)} ${done ? 'done' : 'not done'}',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: Column(
          children: [
            Text(DateFormat('E').format(day).substring(0, 1), style: BasaltType.caption.copyWith(color: p.textFaint, fontSize: 11)),
            const SizedBox(height: 4),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: done ? p.accent : p.fill,
                borderRadius: BorderRadius.circular(6),
              ),
              child: done ? Icon(Icons.check_rounded, size: 14, color: p.onAccent) : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Add (habit == null) or edit a habit in a bottom sheet.
Future<void> editHabit(BuildContext context, WidgetRef ref, HabitRow? habit) async {
  final name = TextEditingController(text: habit?.name ?? '');
  final note = TextEditingController(text: habit?.description ?? '');
  var active = habit?.isActive ?? true;
  await showFormSheet<void>(
    context,
    title: habit == null ? 'New habit' : 'Edit habit',
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            autofocus: habit == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Read 20 pages'),
          ),
          const SizedBox(height: Gap.md),
          TextField(
            controller: note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Why or when (optional)'),
          ),
          if (habit != null) ...[
            const SizedBox(height: Gap.md),
            BGroup(
              children: [
                SwitchRow(
                  title: 'Active',
                  subtitle: 'Paused habits are kept but hidden from Today',
                  value: active,
                  onChanged: (v) => setSheet(() => active = v),
                ),
              ],
            ),
          ],
          const SizedBox(height: Gap.lg),
          BButton(
            label: 'Save',
            expand: true,
            onPressed: () async {
              final n = name.text.trim();
              if (n.isEmpty) {
                BToast.show(ctx, 'Give the habit a name');
                return;
              }
              final d = note.text.trim();
              await ref.read(repoProvider).saveHabit(id: habit?.id, name: n, description: d.isEmpty ? null : d, active: active);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
          if (habit != null) ...[
            const SizedBox(height: Gap.sm),
            BButton(
              label: 'Delete habit',
              variant: BButtonVariant.ghost,
              expand: true,
              onPressed: () async {
                final ok = await bConfirm(ctx, title: 'Delete habit?', message: 'Its history and streaks will be deleted too.', confirmLabel: 'Delete', danger: true);
                if (!ok) return;
                await ref.read(repoProvider).deleteHabit(habit.id);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
          ],
        ],
      ),
    ),
  );
  // The controllers are left to the garbage collector: the sheet may still be animating out.
}
