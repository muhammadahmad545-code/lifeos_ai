import 'package:basalt/basalt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/dates.dart';
import '../logic/rules.dart';
import '../providers.dart';
import 'assistant.dart';
import 'calendar.dart';
import 'common.dart';
import 'focus.dart';
import 'habits.dart';
import 'search.dart';
import 'settings.dart';
import 'tasks.dart';

String greeting(DateTime now) {
  if (now.hour < 5) return 'Good night';
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 18) return 'Good afternoon';
  return 'Good evening';
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.basalt;
    final now = DateTime.now();
    final todayKey = dayKey(now);
    final tabs = ref.read(tabControllerProvider);

    final all = ref.watch(tasksProvider).list;
    final subs = <String, List<TaskRow>>{};
    for (final t in all) {
      if (t.parentId != null) subs.putIfAbsent(t.parentId!, () => []).add(t);
    }
    final due = all.where((t) {
      if (t.parentId != null || t.isCompleted) return false;
      final b = dueBucket(t.dueDate, now);
      return b == DueBucket.overdue || b == DueBucket.today;
    }).toList()
      ..sort((a, b) {
        final c = b.priority.compareTo(a.priority);
        return c != 0 ? c : a.dueDate!.compareTo(b.dueDate!);
      });
    final doneToday = all.where((t) => t.parentId == null && t.isCompleted && sameDay(t.updatedAt, now)).length;

    final habits = ref.watch(habitsProvider).list.where((h) => h.isActive).toList();
    final days = ref.watch(habitDaysProvider);
    final habitsDone = habits.where((h) => days[h.id]?.contains(todayKey) ?? false).length;

    final events = eventsOn(ref.watch(eventsProvider).list, now);
    final sessions = ref.watch(focusSessionsProvider).list;
    final focusToday = focusMinutesBetween(sessions, dateOnly(now), addDays(dateOnly(now), 1));
    final timer = ref.watch(focusTimerProvider);

    return BPage(
      title: 'Today',
      subtitle: '${greeting(now)} · ${fmtDate(now, now: now)}',
      actions: [
        IconAction(icon: Icons.search_rounded, label: 'Search', onPressed: () => push(context, const SearchPage())),
        IconAction(icon: Icons.settings_outlined, label: 'Settings', onPressed: () => push(context, const SettingsPage())),
      ],
      children: [
        const UpdateCard(),
        Row(
          children: [
            Expanded(
              child: BStatTile(
                label: 'Tasks',
                value: '${due.length}',
                hint: doneToday > 0 ? '$doneToday done' : 'to do',
                icon: Icons.checklist_rounded,
                onTap: () => tabs.index = 1,
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: BStatTile(
                label: 'Habits',
                value: habits.isEmpty ? '–' : '$habitsDone/${habits.length}',
                hint: 'done',
                icon: Icons.local_fire_department_outlined,
                onTap: () => push(context, const HabitsPage()),
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: BStatTile(
                label: 'Focus',
                value: '$focusToday',
                hint: 'minutes',
                icon: Icons.timer_outlined,
                onTap: () => push(context, const FocusPage()),
              ),
            ),
          ],
        ),
        BSectionTitle('Due today', action: 'All tasks', onAction: () => tabs.index = 1),
        if (due.isEmpty)
          BCard(
            onTap: () => push(context, TaskEditor(initialDue: dateOnly(now))),
            child: Row(
              children: [
                BIconTile(Icons.check_rounded, color: p.success),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    doneToday > 0 ? 'All done for today. Nice work.' : 'Nothing due today. Tap to add a task.',
                    style: BasaltType.body.copyWith(color: p.textMuted),
                  ),
                ),
              ],
            ),
          )
        else
          BGroup(children: [for (final t in due.take(8)) TaskTile(task: t, subtasks: subs[t.id] ?? const [])]),
        if (due.length > 8)
          Align(
            alignment: Alignment.centerRight,
            child: BButton(label: '${due.length - 8} more', variant: BButtonVariant.ghost, onPressed: () => tabs.index = 1),
          ),
        if (habits.isNotEmpty) ...[
          BSectionTitle('Habits', action: 'Open', onAction: () => push(context, const HabitsPage())),
          BGroup(
            children: [
              for (final h in habits)
                Builder(
                  builder: (context) {
                    final set = days[h.id] ?? const <String>{};
                    final done = set.contains(todayKey);
                    final streak = currentStreak(set, now);
                    return BListRow(
                      leading: CheckCircle(
                        done: done,
                        label: done ? 'Undo ${h.name} today' : 'Check off ${h.name}',
                        onTap: () => toggleHabitToday(ref, h, done),
                      ),
                      title: h.name,
                      subtitle: streak > 0 ? '$streak-day streak' : 'Start a streak today',
                    );
                  },
                ),
            ],
          ),
        ],
        BSectionTitle('Schedule', action: 'Calendar', onAction: () => tabs.index = 3),
        if (events.isEmpty)
          BCard(child: Text('No events today.', style: BasaltType.body.copyWith(color: p.textMuted)))
        else
          BGroup(children: [for (final e in events) EventRow(event: e)]),
        const BSectionTitle('Focus and assistant'),
        BGroup(
          children: [
            BListRow(
              icon: Icons.timer_outlined,
              title: timer.active ? 'Focus session ${timer.running ? 'running' : 'paused'}' : 'Start a focus session',
              subtitle: timer.active ? '${fmtClock(timer.remaining)} left' : '${timer.minutes} minutes, no distractions',
              chevron: true,
              onTap: () => push(context, const FocusPage()),
            ),
            BListRow(
              icon: Icons.auto_awesome_outlined,
              title: 'Ask the assistant',
              subtitle: "Plan my day, what's overdue, spending this month",
              chevron: true,
              onTap: () => push(context, const AssistantPage()),
            ),
          ],
        ),
      ],
    );
  }
}
