import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/feature_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../calendar/domain/calendar_event.dart';
import '../../expenses/domain/expense.dart';
import '../../journal/domain/journal_entry.dart';
import '../../notes/domain/note.dart';
import '../../tasks/domain/task.dart';

class _SearchResult {
  const _SearchResult({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.category,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String category;
  final String route;
}

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<_SearchResult>? _results;
  bool _isSearching = false;
  String _lastQuery = '';

  String? get _userId => ref.read(authSessionProvider).valueOrNull?.id;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final String q = query.trim();
    _lastQuery = q;
    final String? userId = _userId;
    if (q.isEmpty || userId == null) {
      setState(() => _results = null);
      return;
    }
    setState(() => _isSearching = true);

    final List<Task> tasks = await ref.read(taskRepositoryProvider).searchTasks(userId, q);
    final List<Note> notes = await ref.read(noteRepositoryProvider).searchNotes(userId, q);
    final List<JournalEntry> journal = await ref.read(journalRepositoryProvider).searchEntries(userId, q);
    final List<Expense> expenses = (await ref.read(expenseRepositoryProvider).getExpenses(userId))
        .where(
          (Expense e) =>
              e.description.toLowerCase().contains(q.toLowerCase()) ||
              e.category.toLowerCase().contains(q.toLowerCase()),
        )
        .toList();
    final DateTime now = DateTime.now();
    final List<CalendarEvent> events = (await ref.read(calendarRepositoryProvider).getEventsInRange(
          userId,
          now.subtract(const Duration(days: 365)),
          now.add(const Duration(days: 365)),
        ))
        .where(
          (CalendarEvent e) =>
              e.title.toLowerCase().contains(q.toLowerCase()) ||
              (e.location?.toLowerCase().contains(q.toLowerCase()) ?? false),
        )
        .toList();

    if (!mounted || _lastQuery != q) {
      return;
    }

    final List<_SearchResult> results = <_SearchResult>[
      ...tasks.map(
        (Task t) => _SearchResult(
          title: t.title,
          subtitle: t.isCompleted ? 'Task · done' : 'Task · ${t.priority.label}',
          icon: Icons.check_circle_outline,
          category: 'Tasks',
          route: '/tasks',
        ),
      ),
      ...notes.map(
        (Note n) => _SearchResult(
          title: n.title.isEmpty ? '(untitled)' : n.title,
          subtitle: 'Note${n.folder != null ? ' · ${n.folder}' : ''}',
          icon: Icons.sticky_note_2_outlined,
          category: 'Notes',
          route: '/notes',
        ),
      ),
      ...journal.map(
        (JournalEntry j) => _SearchResult(
          title: j.title.isEmpty ? '(untitled)' : j.title,
          subtitle: 'Journal${j.mood != null ? ' · ${j.mood}' : ''}',
          icon: Icons.menu_book_outlined,
          category: 'Journal',
          route: '/journal',
        ),
      ),
      ...expenses.map(
        (Expense e) => _SearchResult(
          title: e.description,
          subtitle: '${e.isIncome ? 'Income' : 'Expense'} · ${e.category} · ${DateFormat.MMMd().format(e.date)}',
          icon: Icons.payments_outlined,
          category: 'Expenses',
          route: '/expenses',
        ),
      ),
      ...events.map(
        (CalendarEvent e) => _SearchResult(
          title: e.title,
          subtitle: 'Event · ${DateFormat.MMMd().add_jm().format(e.startTime)}',
          icon: Icons.event_outlined,
          category: 'Calendar',
          route: '/calendar',
        ),
      ),
    ];

    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<_SearchResult>? results = _results;
    final Map<String, List<_SearchResult>> grouped = <String, List<_SearchResult>>{};
    if (results != null) {
      for (final _SearchResult r in results) {
        grouped.putIfAbsent(r.category, () => <_SearchResult>[]).add(r);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _performSearch,
              decoration: InputDecoration(
                hintText: 'Search tasks, notes, journal, expenses, events...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: _isSearching
                ? const LoadingView()
                : results == null
                    ? const EmptyStateView(
                        title: 'Search your LifeOS',
                        message: 'Find tasks, notes, journal entries, expenses, and calendar events in one place.',
                      )
                    : results.isEmpty
                        ? const EmptyStateView(title: 'No results found', message: 'Try a different search term.')
                        : ListView(
                            padding: const EdgeInsets.only(bottom: 24),
                            children: grouped.entries.map((MapEntry<String, List<_SearchResult>> entry) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                                    child: Text(
                                      entry.key,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(color: Theme.of(context).colorScheme.primary),
                                    ),
                                  ),
                                  ...entry.value.map(
                                    (_SearchResult r) => ListTile(
                                      leading: Icon(r.icon),
                                      title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      subtitle: Text(r.subtitle),
                                      onTap: () => context.push(r.route),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
          ),
        ],
      ),
    );
  }
}
