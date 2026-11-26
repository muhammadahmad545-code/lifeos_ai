import 'package:basalt/basalt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/dates.dart';
import '../providers.dart';
import 'assistant.dart';
import 'common.dart';
import 'expenses.dart';
import 'focus.dart';
import 'goals.dart';
import 'habits.dart';
import 'insights.dart';
import 'journal.dart';
import 'search.dart';
import 'settings.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(moneyProvider);
    final now = DateTime.now();
    final todayKey = dayKey(now);
    final habits = ref.watch(habitsProvider).list.where((h) => h.isActive).toList();
    final days = ref.watch(habitDaysProvider);
    final habitsDone = habits.where((h) => days[h.id]?.contains(todayKey) ?? false).length;
    final journal = ref.watch(journalProvider).list;
    final spent = ref
        .watch(expensesProvider)
        .list
        .where((e) => !e.isIncome && inMonth(e.date, now))
        .fold<double>(0, (s, e) => s + e.amount);
    final goals = ref.watch(goalsProvider).list.where((g) => !g.isCompleted).length;
    final timer = ref.watch(focusTimerProvider);

    return BPage(
      title: 'More',
      children: [
        BGroup(
          title: 'Track',
          children: [
            BListRow(
              icon: Icons.local_fire_department_outlined,
              title: 'Habits',
              subtitle: habits.isEmpty ? 'Build daily streaks' : '$habitsDone of ${habits.length} done today',
              chevron: true,
              onTap: () => push(context, const HabitsPage()),
            ),
            BListRow(
              icon: Icons.book_outlined,
              title: 'Journal',
              subtitle: journal.isEmpty ? 'Write a few lines a day' : '${journal.length} ${journal.length == 1 ? 'entry' : 'entries'}',
              chevron: true,
              onTap: () => push(context, const JournalPage()),
            ),
            BListRow(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Expenses',
              subtitle: '${money(spent)} spent this month',
              chevron: true,
              onTap: () => push(context, const ExpensesPage()),
            ),
            BListRow(
              icon: Icons.flag_outlined,
              title: 'Goals',
              subtitle: goals == 0 ? 'Set targets with milestones' : '$goals active',
              chevron: true,
              onTap: () => push(context, const GoalsPage()),
            ),
            BListRow(
              icon: Icons.insights_rounded,
              title: 'Task insights',
              subtitle: 'Done today, streak, this week and open tasks by category',
              chevron: true,
              onTap: () => push(context, const InsightsPage()),
            ),
            BListRow(
              icon: Icons.timer_outlined,
              title: 'Focus timer',
              subtitle: timer.active ? '${timer.running ? 'Running' : 'Paused'} · ${fmtClock(timer.remaining)} left' : 'Pomodoro-style sessions',
              chevron: true,
              onTap: () => push(context, const FocusPage()),
            ),
          ],
        ),
        BGroup(
          title: 'Tools',
          children: [
            BListRow(
              icon: Icons.auto_awesome_outlined,
              title: 'Assistant',
              subtitle: 'On-device answers about your day, money and habits',
              chevron: true,
              onTap: () => push(context, const AssistantPage()),
            ),
            BListRow(
              icon: Icons.search_rounded,
              title: 'Search',
              subtitle: 'Find anything you have saved',
              chevron: true,
              onTap: () => push(context, const SearchPage()),
            ),
            BListRow(
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: 'Theme, reminders, app lock, quick access, backup and updates',
              chevron: true,
              onTap: () => push(context, const SettingsPage()),
            ),
          ],
        ),
      ],
    );
  }
}
