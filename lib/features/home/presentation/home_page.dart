import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/feature_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/dashboard_card.dart';
import '../../../shared/widgets/premium_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../assistant/domain/lifeos_ai_engine.dart';
import '../../auth/domain/auth_user.dart';
import '../../calendar/domain/calendar_event.dart';
import '../../health/domain/health_log.dart';
import '../../notes/domain/note.dart';

const List<String> _dailyQuotes = <String>[
  'Small daily improvements lead to staggering long-term results.',
  'Discipline is choosing between what you want now and what you want most.',
  'Focus on progress, not perfection.',
  'The days are long, but the years are short — make today count.',
  'You do not have to be great to start, but you have to start to be great.',
  'Consistency beats intensity over time.',
  'Every habit you build today is a vote for the person you want to become.',
];

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Future<void> _refresh() async {
    ref.invalidate(watchTasksProvider);
    ref.invalidate(watchNotesProvider);
    ref.invalidate(watchCalendarEventsProvider);
    ref.invalidate(watchHabitsProvider);
    ref.invalidate(watchJournalEntriesProvider);
    ref.invalidate(healthLogsProvider(HealthLogType.water));
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (mounted) {
      context.go('/login');
    }
  }

  String _greeting(String name) {
    final int hour = DateTime.now().hour;
    final String part = hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening');
    return '$part, $name';
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AuthUser?> session = ref.watch(authSessionProvider);
    final AuthUser? user = session.valueOrNull;
    final DateTime now = DateTime.now();

    final tasksAsync = ref.watch(watchTasksProvider);
    final notesAsync = ref.watch(watchNotesProvider);
    final eventsAsync = ref.watch(watchCalendarEventsProvider);
    final habitsAsync = ref.watch(watchHabitsProvider);
    final journalAsync = ref.watch(watchJournalEntriesProvider);
    final waterAsync = ref.watch(healthLogsProvider(HealthLogType.water));
    final expensesAsync = ref.watch(watchExpensesProvider);
    final goalsAsync = ref.watch(watchGoalsProvider);

    final int totalTasks = tasksAsync.valueOrNull?.length ?? 0;
    final int completedTasks = tasksAsync.valueOrNull?.where((t) => t.isCompleted).length ?? 0;
    final double productivity = totalTasks == 0 ? 0 : completedTasks / totalTasks;
    final int todayTasks = tasksAsync.valueOrNull?.where((t) {
          if (t.isCompleted || t.dueDate == null) {
            return false;
          }
          final DateTime d = t.dueDate!;
          return d.year == now.year && d.month == now.month && d.day == now.day;
        }).length ??
        0;

    final List<CalendarEvent> upcomingEvents = (eventsAsync.valueOrNull ?? const <CalendarEvent>[])
        .where((CalendarEvent e) => e.endTime.isAfter(now))
        .toList()
      ..sort((CalendarEvent a, CalendarEvent b) => a.startTime.compareTo(b.startTime));

    final List<Note> recentNotes = List<Note>.from(notesAsync.valueOrNull ?? const <Note>[])
      ..sort((Note a, Note b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));

    final double waterMl = (waterAsync.valueOrNull ?? const <HealthLog>[])
        .where((HealthLog log) {
          final DateTime d = log.loggedAt;
          return d.year == now.year && d.month == now.month && d.day == now.day;
        })
        .fold<double>(0, (double sum, HealthLog log) => sum + log.value);

    final String? latestMood =
        journalAsync.valueOrNull?.isNotEmpty == true ? journalAsync.valueOrNull!.first.mood : null;

    final int activeHabits = habitsAsync.valueOrNull?.where((h) => h.isActive).length ?? 0;
    final int habitsDoneToday = habitsAsync.valueOrNull?.where((h) {
          if (!h.isActive || h.lastCompletedAt == null) {
            return false;
          }
          final DateTime d = h.lastCompletedAt!;
          return d.year == now.year && d.month == now.month && d.day == now.day;
        }).length ??
        0;

    final String quote = _dailyQuotes[now.day % _dailyQuotes.length];

    final LifeOsAiEngine engine = ref.watch(lifeOsAiEngineProvider);
    final String aiSuggestion = engine.respond(
      userMessage: 'plan my day',
      tasks: tasksAsync.valueOrNull ?? const [],
      habits: habitsAsync.valueOrNull ?? const [],
      expenses: expensesAsync.valueOrNull ?? const [],
      goals: goalsAsync.valueOrNull ?? const [],
      notes: notesAsync.valueOrNull ?? const [],
      journal: journalAsync.valueOrNull ?? const [],
    );
    final String aiSnippet = aiSuggestion.split('\n').take(3).join('\n');

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            SectionHeader(
              title: _greeting(user?.displayName.split(' ').first ?? 'there'),
              subtitle: "Here's your day at a glance.",
            ),
            const SizedBox(height: 16),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Productivity score', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(value: productivity, minHeight: 10),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    totalTasks == 0
                        ? 'No tasks yet — add one to start tracking.'
                        : '${(productivity * 100).round()}% of $totalTasks tasks completed · $todayTasks due today',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(child: _StatTile(icon: Icons.local_drink_outlined, label: 'Water today', value: '${waterMl.round()} ml')),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.emoji_emotions_outlined,
                    label: 'Mood',
                    value: latestMood ?? '—',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _StatTile(
                    icon: Icons.repeat_rounded,
                    label: 'Habits today',
                    value: '$habitsDoneToday / $activeHabits',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.event_outlined,
                    label: 'Upcoming events',
                    value: '${upcomingEvents.length}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SectionHeader(title: 'Quick actions'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ActionChip(avatar: const Icon(Icons.add_task, size: 18), label: const Text('New task'), onPressed: () => context.push('/tasks')),
                ActionChip(avatar: const Icon(Icons.note_add_outlined, size: 18), label: const Text('New note'), onPressed: () => context.push('/notes')),
                ActionChip(avatar: const Icon(Icons.event_available_outlined, size: 18), label: const Text('New event'), onPressed: () => context.push('/calendar')),
                ActionChip(avatar: const Icon(Icons.payments_outlined, size: 18), label: const Text('Add expense'), onPressed: () => context.push('/expenses')),
                ActionChip(avatar: const Icon(Icons.flag_outlined, size: 18), label: const Text('New goal'), onPressed: () => context.push('/goals')),
                ActionChip(avatar: const Icon(Icons.timer_outlined, size: 18), label: const Text('Start focus'), onPressed: () => context.push('/focus')),
              ],
            ),
            const SizedBox(height: 24),
            SectionHeader(title: 'AI suggestion', subtitle: 'From your local LifeOS assistant'),
            const SizedBox(height: 12),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(aiSnippet, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/assistant'),
                      child: const Text('Open assistant'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SectionHeader(title: 'Upcoming events'),
            const SizedBox(height: 12),
            if (upcomingEvents.isEmpty)
              const PremiumCard(child: Text('Nothing scheduled. Enjoy the free time or plan something new.'))
            else
              ...upcomingEvents.take(3).map(
                    (CalendarEvent e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PremiumCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_outlined),
                          title: Text(e.title),
                          subtitle: Text(_formatEventTime(e)),
                          onTap: () => context.push('/calendar'),
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 12),
            SectionHeader(title: 'Recent notes'),
            const SizedBox(height: 12),
            if (recentNotes.isEmpty)
              const PremiumCard(child: Text('No notes yet — capture your first idea.'))
            else
              ...recentNotes.take(3).map(
                    (Note n) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PremiumCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(n.isPinned ? Icons.push_pin : Icons.sticky_note_2_outlined),
                          title: Text(n.title.isEmpty ? '(untitled)' : n.title),
                          subtitle: Text(n.content, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => context.push('/notes'),
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 24),
            SectionHeader(title: 'Explore'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: <Widget>[
                DashboardCard(title: 'Tasks', subtitle: '$totalTasks total', icon: Icons.check_circle_outline, onTap: () => context.push('/tasks')),
                DashboardCard(title: 'Notes', subtitle: '${notesAsync.valueOrNull?.length ?? 0} notes', icon: Icons.note_outlined, onTap: () => context.push('/notes')),
                DashboardCard(title: 'Habits', subtitle: '$activeHabits active', icon: Icons.repeat_outlined, onTap: () => context.push('/habits')),
                DashboardCard(title: 'Journal', subtitle: 'Reflections', icon: Icons.assignment_outlined, onTap: () => context.push('/journal')),
                DashboardCard(title: 'Health', subtitle: 'Wellness log', icon: Icons.favorite_outline, onTap: () => context.push('/health')),
                DashboardCard(title: 'Files', subtitle: 'Documents', icon: Icons.folder_outlined, onTap: () => context.push('/files')),
              ],
            ),
            const SizedBox(height: 24),
            PremiumCard(
              child: Row(
                children: <Widget>[
                  Icon(Icons.format_quote_rounded, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(quote, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic))),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String _formatEventTime(CalendarEvent e) {
    final DateTime s = e.startTime;
    final String date = '${s.month}/${s.day}';
    final String time = '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';
    return e.isAllDay ? '$date · All day' : '$date · $time';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
