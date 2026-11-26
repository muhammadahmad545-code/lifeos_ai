import 'package:basalt/basalt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/rules.dart';
import '../logic/tasks_view.dart';
import '../providers.dart';
import 'common.dart';
import 'tasks.dart';

/// Task insights: what got done today and this week, the streak, what is overdue and where the
/// open tasks are.
class InsightsPage extends ConsumerWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.basalt;
    final i = computeInsights(ref.watch(tasksProvider).list, ref.watch(completionsProvider).list, DateTime.now());
    final rate = i.weekRate;
    final totalOpen = i.openByCategory.values.fold<int>(0, (a, b) => a + b);
    return SubPage(
      title: 'Task insights',
      subtitle: '${i.completedToday} completed today · ${i.streak}-day streak',
      children: [
        Row(
          children: [
            Expanded(child: BStatTile(label: 'Done today', value: '${i.completedToday}', icon: Icons.task_alt_rounded)),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: BStatTile(
                label: 'Streak',
                value: '${i.streak}',
                hint: i.streak == 1 ? 'day' : 'days',
                icon: Icons.local_fire_department_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.sm),
        Row(
          children: [
            Expanded(
              child: BStatTile(
                label: 'This week',
                value: rate == null ? '–' : '${(rate * 100).round()}%',
                hint: '${i.weekDone} of ${i.weekDone + i.weekOpen} done',
                icon: Icons.date_range_outlined,
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: BStatTile(
                label: 'Overdue',
                value: '${i.overdue}',
                icon: Icons.warning_amber_rounded,
                color: i.overdue > 0 ? p.danger : null,
              ),
            ),
          ],
        ),
        const BSectionTitle('Completed, last 7 days'),
        BCard(child: BBars(values: [for (final v in i.last7) v.toDouble()], labels: i.last7Labels, highlight: 6, height: 96)),
        const BSectionTitle('Open by category'),
        BGroup(
          children: [
            for (final c in kTaskCategories)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        BIconTile(categoryIconFor(c), size: 32),
                        const SizedBox(width: Gap.md),
                        Expanded(child: Text(c, style: BasaltType.bodyStrong.copyWith(color: p.text))),
                        Text('${i.openByCategory[c]}', style: BasaltType.bodyStrong.copyWith(color: p.text)),
                      ],
                    ),
                    const SizedBox(height: Gap.sm),
                    BProgressBar(value: totalOpen == 0 ? 0 : i.openByCategory[c]! / totalOpen),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: Gap.md),
        Text(
          'The streak counts days with at least one task completed. This week is Monday to Sunday: '
          'tasks completed, against those completed plus those still open and due this week.',
          style: BasaltType.caption.copyWith(color: p.textFaint),
        ),
      ],
    );
  }
}
