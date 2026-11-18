import 'package:basalt/basalt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/dates.dart';
import '../logic/rules.dart';
import '../providers.dart';
import 'calendar.dart';
import 'common.dart';
import 'expenses.dart';
import 'goals.dart';
import 'habits.dart';
import 'journal.dart';
import 'notes.dart';
import 'tasks.dart';

/// One search across tasks, notes, events, journal, expenses, goals and habits.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  String _q = '';

  bool _has(String? s) => s != null && s.toLowerCase().contains(_q.trim().toLowerCase());

  @override
  Widget build(BuildContext context) {
    final p = context.basalt;
    final money = ref.watch(moneyProvider);
    final q = _q.trim();
    final now = DateTime.now();
    final sections = <Widget>[];

    if (q.isNotEmpty) {
      final tasks = ref.watch(tasksProvider).list.where((t) => _has(t.title) || _has(t.description)).toList()
        ..sort((a, b) => a.isCompleted == b.isCompleted ? b.updatedAt.compareTo(a.updatedAt) : (a.isCompleted ? 1 : -1));
      final notes = ref.watch(notesProvider).list.where((n) => noteMatches(n, q)).toList();
      final events = ref.watch(eventsProvider).list.where((e) => _has(e.title) || _has(e.location) || _has(e.description)).toList()
        ..sort((a, b) => b.startTime.compareTo(a.startTime));
      final journal = ref.watch(journalProvider).list.where((j) => _has(j.title) || _has(j.content)).toList();
      final expenses = ref.watch(expensesProvider).list.where((e) => _has(e.description) || _has(e.category)).toList();
      final goals = ref.watch(goalsProvider).list.where((g) => _has(g.title) || _has(g.description) || _has(g.milestones)).toList();
      final habits = ref.watch(habitsProvider).list.where((h) => _has(h.name) || _has(h.description)).toList();

      void add(String title, List<Widget> rows) {
        if (rows.isEmpty) return;
        sections.add(BGroup(title: '$title  ${rows.length}', children: rows.take(20).toList()));
      }

      add('Tasks', [for (final t in tasks) TaskTile(task: t)]);
      add('Notes', [
        for (final n in notes)
          BListRow(
            icon: Icons.sticky_note_2_outlined,
            title: n.title.trim().isEmpty ? 'Untitled' : n.title,
            subtitle: n.content.trim().isNotEmpty
                ? n.content.trim().replaceAll('\n', ' ')
                : decodeChecklist(n.checklist).map((i) => i.text).join(', '),
            onTap: () => push(context, NoteEditor(note: n)),
          ),
      ]);
      add('Events', [for (final e in events) EventRow(event: e)]);
      add('Journal', [
        for (final j in journal)
          BListRow(
            icon: moodIcon(j.mood),
            title: j.title.trim().isEmpty ? fmtDate(j.createdAt, now: now) : j.title,
            subtitle: j.content.trim().replaceAll('\n', ' '),
            onTap: () => push(context, JournalEditor(entry: j)),
          ),
      ]);
      add('Expenses', [
        for (final e in expenses)
          BListRow(
            icon: categoryIcon(e.category),
            title: e.description,
            subtitle: '${e.category} · ${fmtDate(e.date, now: now)}',
            trailing: Text(
              e.isIncome ? '+${money(e.amount)}' : money(e.amount),
              style: BasaltType.bodyStrong.copyWith(color: e.isIncome ? p.success : p.text),
            ),
            onTap: () => push(context, ExpenseEditor(expense: e)),
          ),
      ]);
      add('Goals', [
        for (final g in goals)
          BListRow(icon: Icons.flag_outlined, title: g.title, subtitle: goalWhen(g, now), onTap: () => push(context, GoalEditor(goal: g))),
      ]);
      add('Habits', [
        for (final h in habits)
          BListRow(
            icon: Icons.local_fire_department_outlined,
            title: h.name,
            subtitle: h.description,
            onTap: () => editHabit(context, ref, h),
          ),
      ]);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxxl),
        children: [
          BSearchField(hint: 'Search everything', autofocus: true, onChanged: (v) => setState(() => _q = v)),
          if (q.isEmpty)
            const BEmptyState(
              icon: Icons.search_rounded,
              title: 'Search LifeOS',
              message: 'Find tasks, notes, events, journal entries, expenses, goals and habits.',
            )
          else if (sections.isEmpty)
            BEmptyState(icon: Icons.search_off_rounded, title: 'No results', message: 'Nothing matches "$q".')
          else
            for (final s in sections) Padding(padding: const EdgeInsets.only(top: Gap.sm), child: s),
        ],
      ),
    );
  }
}
