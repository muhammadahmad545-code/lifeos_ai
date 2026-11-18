import 'package:basalt/basalt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/dates.dart';
import '../providers.dart';
import '../services/reminders.dart';
import 'common.dart';

String fmtClock(Duration d) {
  final s = d.inSeconds;
  final m = s ~/ 60;
  return '${m.toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

int focusMinutesBetween(List<FocusSessionRow> sessions, DateTime from, DateTime to) => sessions
    .where((f) => !f.startedAt.isBefore(from) && f.startedAt.isBefore(to))
    .fold<int>(0, (s, f) => s + f.completedMinutes);

class FocusPage extends ConsumerWidget {
  const FocusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.basalt;
    final timer = ref.watch(focusTimerProvider);
    final sessions = ref.watch(focusSessionsProvider).list;
    final today = dateOnly(DateTime.now());
    final todayMin = focusMinutesBetween(sessions, today, addDays(today, 1));
    final weekStart = addDays(today, -(today.weekday - 1));
    final weekMin = focusMinutesBetween(sessions, weekStart, addDays(today, 1));
    final week = [for (var i = 0; i < 7; i++) focusMinutesBetween(sessions, addDays(weekStart, i), addDays(weekStart, i + 1)).toDouble()];

    final status = timer.running
        ? 'Focusing'
        : timer.paused
            ? 'Paused'
            : (timer.lastCompletedAt != null ? 'Session complete. Take a break.' : 'Ready');

    return SubPage(
      title: 'Focus',
      subtitle: 'Work in short, distraction-free blocks',
      children: [
        BCard(
          padding: const EdgeInsets.all(Gap.xl),
          child: Column(
            children: [
              BRing(
                value: timer.active ? timer.progress : 0,
                size: 200,
                stroke: 10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(fmtClock(timer.remaining), style: BasaltType.hero.copyWith(color: p.text, fontSize: 40, fontFeatures: const [FontFeature.tabularFigures()])),
                    const SizedBox(height: Gap.xs),
                    Text(status, style: BasaltType.label.copyWith(color: timer.running ? p.accent : p.textMuted)),
                  ],
                ),
              ),
              const SizedBox(height: Gap.xl),
              if (!timer.active)
                ChipWrap(
                  children: [
                    for (final m in const [15, 25, 45, 60])
                      BChip(label: '$m min', selected: timer.minutes == m, onTap: () => ref.read(focusTimerProvider).setMinutes(m)),
                  ],
                ),
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  if (timer.active) ...[
                    Expanded(
                      child: BButton(
                        label: 'Stop',
                        variant: BButtonVariant.secondary,
                        expand: true,
                        onPressed: () => ref.read(focusTimerProvider).stop(),
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                  ],
                  Expanded(
                    child: BButton(
                      label: timer.running ? 'Pause' : (timer.paused ? 'Resume' : 'Start focus'),
                      icon: timer.running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      expand: true,
                      onPressed: () {
                        final t = ref.read(focusTimerProvider);
                        if (t.running) {
                          t.pause();
                        } else {
                          // Ask once so the "session complete" alert can show when the app is in the background.
                          Reminders.instance.ensurePermission();
                          t.start();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        Row(
          children: [
            Expanded(child: BStatTile(label: 'Today', value: '$todayMin min', icon: Icons.timer_outlined)),
            const SizedBox(width: Gap.md),
            Expanded(child: BStatTile(label: 'This week', value: '$weekMin min', icon: Icons.date_range_outlined)),
          ],
        ),
        const SizedBox(height: Gap.md),
        BCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This week', style: BasaltType.label.copyWith(color: p.textMuted)),
              const SizedBox(height: Gap.md),
              BBars(values: week, labels: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'], highlight: today.weekday - 1, height: 72),
            ],
          ),
        ),
        if (sessions.isNotEmpty) ...[
          const BSectionTitle('Recent sessions'),
          BGroup(
            children: [
              for (final s in sessions.take(8))
                BListRow(
                  dense: true,
                  icon: s.completed ? Icons.check_circle_outline_rounded : Icons.timelapse_rounded,
                  iconColor: s.completed ? p.success : p.textMuted,
                  title: '${s.completedMinutes} min${s.completed ? '' : ' of ${s.durationMinutes}'}',
                  subtitle: '${relativeDay(s.startedAt)} at ${fmtTime(s.startedAt)}',
                ),
            ],
          ),
        ],
      ],
    );
  }
}
