import '../../expenses/domain/expense.dart';
import '../../goals/domain/goal.dart';
import '../../habits/domain/habit.dart';
import '../../journal/domain/journal_entry.dart';
import '../../notes/domain/note.dart';
import '../../tasks/domain/task.dart';

/// Local, offline assistant that turns LifeOS context into actionable replies.
/// No network calls — intent detection + heuristic reasoning over in-app data.
class LifeOsAiEngine {
  const LifeOsAiEngine();

  String respond({
    required String userMessage,
    List<Task> tasks = const <Task>[],
    List<Note> notes = const <Note>[],
    List<Habit> habits = const <Habit>[],
    List<Expense> expenses = const <Expense>[],
    List<Goal> goals = const <Goal>[],
    List<JournalEntry> journal = const <JournalEntry>[],
  }) {
    final String message = userMessage.trim();
    if (message.isEmpty) {
      return 'Ask me anything about your tasks, notes, habits, spending, goals, or journal. '
          'I work fully offline using your LifeOS data.';
    }

    final String lower = message.toLowerCase();
    final _Intent intent = _detectIntent(lower);

    return switch (intent) {
      _Intent.planning => _planning(tasks, goals, habits, expenses),
      _Intent.prioritize => _prioritizeTasks(tasks, message),
      _Intent.noteSummary => _summarizeNotes(notes, message),
      _Intent.habitTips => _habitTips(habits),
      _Intent.expenseInsights => _expenseInsights(expenses, message),
      _Intent.journalReflection => _journalReflection(journal, message),
      _Intent.translate => _translate(message),
      _Intent.brainstorm => _brainstorm(message, notes, goals, tasks),
      _Intent.overview => _overview(tasks, notes, habits, expenses, goals, journal),
      _Intent.general => _generalChat(message, tasks, habits, goals),
    };
  }

  _Intent _detectIntent(String lower) {
    if (_matches(lower, const <String>[
      'plan my day',
      'plan today',
      'daily plan',
      'schedule',
      'what should i do',
      'agenda',
      'roadmap',
    ])) {
      return _Intent.planning;
    }
    if (_matches(lower, const <String>[
      'priorit',
      'what first',
      'most important',
      'urgent',
      'focus on',
      'which task',
    ])) {
      return _Intent.prioritize;
    }
    if (_matches(lower, const <String>[
      'summar',
      'summarize notes',
      'note summary',
      'what are my notes',
      'recap notes',
    ])) {
      return _Intent.noteSummary;
    }
    if (_matches(lower, const <String>[
      'habit',
      'streak',
      'consistency',
      'routine tip',
      'build habit',
    ])) {
      return _Intent.habitTips;
    }
    if (_matches(lower, const <String>[
      'expense',
      'spend',
      'budget',
      'money',
      'income',
      'finance',
      'how much',
    ])) {
      return _Intent.expenseInsights;
    }
    if (_matches(lower, const <String>[
      'journal',
      'reflect',
      'mood',
      'how am i feeling',
      'diary',
    ])) {
      return _Intent.journalReflection;
    }
    if (_matches(lower, const <String>[
      'translate',
      'traducir',
      'traduire',
      'übersetz',
      'in spanish',
      'in french',
      'in german',
      'in urdu',
      'in arabic',
    ])) {
      return _Intent.translate;
    }
    if (_matches(lower, const <String>[
      'brainstorm',
      'ideas for',
      'suggest ideas',
      'creative',
      'come up with',
    ])) {
      return _Intent.brainstorm;
    }
    if (_matches(lower, const <String>[
      'overview',
      'status',
      'dashboard',
      'how am i doing',
      'summary of my life',
      'life summary',
    ])) {
      return _Intent.overview;
    }
    return _Intent.general;
  }

  bool _matches(String lower, List<String> needles) {
    for (final String needle in needles) {
      if (lower.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  String _planning(
    List<Task> tasks,
    List<Goal> goals,
    List<Habit> habits,
    List<Expense> expenses,
  ) {
    final DateTime now = DateTime.now();
    final List<Task> open = tasks.where((Task t) => !t.isCompleted).toList()
      ..sort((Task a, Task b) {
        final int byPriority = b.priority.index.compareTo(a.priority.index);
        if (byPriority != 0) {
          return byPriority;
        }
        final DateTime aDue = a.dueDate ?? DateTime(9999);
        final DateTime bDue = b.dueDate ?? DateTime(9999);
        return aDue.compareTo(bDue);
      });

    final List<Habit> dueHabits = habits.where((Habit h) {
      if (!h.isActive) {
        return false;
      }
      if (h.lastCompletedAt == null) {
        return true;
      }
      final DateTime last = h.lastCompletedAt!;
      return last.year != now.year || last.month != now.month || last.day != now.day;
    }).toList();

    final List<Goal> activeGoals = goals.where((Goal g) => !g.isCompleted).toList()
      ..sort((Goal a, Goal b) => a.targetDate.compareTo(b.targetDate));

    final StringBuffer buf = StringBuffer()
      ..writeln('Here is a focused plan for today:')
      ..writeln();

    buf.writeln('1) Morning focus (deep work)');
    if (open.isEmpty) {
      buf.writeln('   • No open tasks — create 1–3 concrete outcomes for today.');
    } else {
      for (final Task task in open.take(3)) {
        buf.writeln('   • ${_taskLine(task)}');
      }
    }

    buf.writeln();
    buf.writeln('2) Habits & energy');
    if (dueHabits.isEmpty) {
      buf.writeln('   • All active habits look completed for today — protect the streak.');
    } else {
      for (final Habit habit in dueHabits.take(4)) {
        buf.writeln('   • ${habit.name} (streak ${habit.currentStreak}, L${habit.level})');
      }
    }

    buf.writeln();
    buf.writeln('3) Goals check-in');
    if (activeGoals.isEmpty) {
      buf.writeln('   • No active goals — set one weekly milestone to steer the day.');
    } else {
      final Goal top = activeGoals.first;
      final int daysLeft = top.targetDate.difference(now).inDays;
      buf.writeln(
        '   • Advance "${top.title}" (${(top.progress * 100).round()}%, '
        '${daysLeft >= 0 ? '$daysLeft days left' : '${-daysLeft} days overdue'}).',
      );
      if (top.milestones.isNotEmpty) {
        buf.writeln('   • Next milestone hint: ${top.milestones.first}');
      }
    }

    final ExpenseTotals month = _monthTotals(expenses, now);
    buf
      ..writeln()
      ..writeln('4) Money pulse')
      ..writeln(
        '   • This month: income ${_money(month.income)}, '
        'spent ${_money(month.expense)}, net ${_money(month.net)}.',
      )
      ..writeln()
      ..writeln('Tip: batch similar tasks, finish one high-priority item before noon, '
          'and log habits as soon as you finish them.');

    return buf.toString().trim();
  }

  String _prioritizeTasks(List<Task> tasks, String message) {
    final List<Task> open = tasks.where((Task t) => !t.isCompleted).toList();
    if (open.isEmpty) {
      return 'You have no open tasks. Capture the next 3 outcomes you care about, '
          'then ask me to prioritize them.';
    }

    open.sort((Task a, Task b) {
      final int scoreA = _taskScore(a);
      final int scoreB = _taskScore(b);
      return scoreB.compareTo(scoreA);
    });

    final StringBuffer buf = StringBuffer()
      ..writeln('Priority order (urgency × importance × deadline):')
      ..writeln();

    for (int i = 0; i < open.length && i < 7; i++) {
      final Task task = open[i];
      buf.writeln('${i + 1}. ${_taskLine(task)}  [score ${_taskScore(task)}]');
    }

    final Task top = open.first;
    buf
      ..writeln()
      ..writeln('Start with: "${top.title}".')
      ..writeln(
        'Reason: ${top.priority.label} priority'
        '${top.dueDate != null ? ', due ${_fmtDate(top.dueDate!)}' : ''}'
        '${top.project != null ? ', project ${top.project}' : ''}.',
      );

    if (message.toLowerCase().contains('tonight') || message.toLowerCase().contains('evening')) {
      buf.writeln('For evening bandwidth, pick at most 2 items from the top of this list.');
    }

    return buf.toString().trim();
  }

  int _taskScore(Task task) {
    int score = task.priority.index * 10;
    if (task.dueDate != null) {
      final int days = task.dueDate!.difference(DateTime.now()).inDays;
      if (days < 0) {
        score += 40;
      } else if (days == 0) {
        score += 30;
      } else if (days <= 2) {
        score += 20;
      } else if (days <= 7) {
        score += 10;
      }
    }
    if (task.labels.any((String l) => l.toLowerCase().contains('urgent'))) {
      score += 15;
    }
    return score;
  }

  String _summarizeNotes(List<Note> notes, String message) {
    final List<Note> active = notes.where((Note n) => !n.isArchived).toList();
    if (active.isEmpty) {
      return 'No notes yet. Write a quick brain dump, then ask me to summarize themes.';
    }

    String? folderFilter;
    final RegExp folderRe = RegExp(r'folder[:\s]+([a-z0-9 _-]+)', caseSensitive: false);
    final Match? folderMatch = folderRe.firstMatch(message);
    if (folderMatch != null) {
      folderFilter = folderMatch.group(1)?.trim().toLowerCase();
    }

    Iterable<Note> scoped = active;
    if (folderFilter != null && folderFilter.isNotEmpty) {
      scoped = active.where((Note n) => (n.folder ?? '').toLowerCase().contains(folderFilter!));
    }

    final List<Note> list = scoped.toList()
      ..sort((Note a, Note b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        return (b.updatedAt ?? b.createdAt ?? DateTime(0))
            .compareTo(a.updatedAt ?? a.createdAt ?? DateTime(0));
      });

    if (list.isEmpty) {
      return 'No notes matched that filter. Try without a folder name.';
    }

    final Map<String, int> tagCounts = <String, int>{};
    for (final Note note in list) {
      for (final String tag in note.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    final List<MapEntry<String, int>> topTags = tagCounts.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));

    final StringBuffer buf = StringBuffer()
      ..writeln('Notes snapshot (${list.length}${folderFilter != null ? ' in "$folderFilter"' : ''}):')
      ..writeln();

    for (final Note note in list.take(5)) {
      final String snippet = _snippet(note.content, 90);
      buf.writeln(
        '• ${note.isPinned ? '📌 ' : ''}${note.title}'
        '${note.folder != null ? ' [${note.folder}]' : ''}'
        '${snippet.isEmpty ? '' : ' — $snippet'}',
      );
    }

    if (topTags.isNotEmpty) {
      buf
        ..writeln()
        ..writeln(
          'Recurring themes: ${topTags.take(5).map((MapEntry<String, int> e) => '${e.key} (${e.value})').join(', ')}.',
        );
    }

    final int favorites = list.where((Note n) => n.isFavorite).length;
    buf
      ..writeln()
      ..writeln(
        'Pinned: ${list.where((Note n) => n.isPinned).length}, '
        'favorites: $favorites. '
        'Ask me to brainstorm from a specific note title for deeper ideas.',
      );

    return buf.toString().trim();
  }

  String _habitTips(List<Habit> habits) {
    if (habits.isEmpty) {
      return 'Start with one tiny daily habit (2 minutes). Name it clearly, attach it to an '
          'existing cue (after coffee / after brushing teeth), and log it in LifeOS every day.';
    }

    final List<Habit> active = habits.where((Habit h) => h.isActive).toList();
    final Habit? strongest = active.isEmpty
        ? null
        : (List<Habit>.from(active)..sort((Habit a, Habit b) => b.currentStreak.compareTo(a.currentStreak))).first;
    final Habit? weakest = active.isEmpty
        ? null
        : (List<Habit>.from(active)..sort((Habit a, Habit b) => a.currentStreak.compareTo(b.currentStreak))).first;

    final DateTime now = DateTime.now();
    final int pendingToday = active.where((Habit h) {
      if (h.lastCompletedAt == null) {
        return true;
      }
      final DateTime last = h.lastCompletedAt!;
      return last.year != now.year || last.month != now.month || last.day != now.day;
    }).length;

    final StringBuffer buf = StringBuffer()
      ..writeln('Habit coaching from your current data:')
      ..writeln();

    if (strongest != null) {
      buf.writeln(
        '• Strongest: "${strongest.name}" — streak ${strongest.currentStreak}, '
        'best ${strongest.longestStreak}, XP ${strongest.xp}, level ${strongest.level}. '
        'Protect this one; it is your identity habit.',
      );
    }
    if (weakest != null && strongest != null && weakest.id != strongest.id) {
      buf.writeln(
        '• Needs care: "${weakest.name}" (streak ${weakest.currentStreak}). '
        'Shrink it to a 60-second version until it sticks for 7 days.',
      );
    }

    buf
      ..writeln('• Pending today: $pendingToday of ${active.length} active habits.')
      ..writeln()
      ..writeln('Playbook:')
      ..writeln('1. Stack weak habits after your strongest cue.')
      ..writeln('2. Never miss twice — a single miss is data, two is a new pattern.')
      ..writeln('3. Celebrate XP/level gains; they reinforce the loop.')
      ..writeln('4. Review weekly: keep / tweak / pause any habit below 50% adherence.');

    return buf.toString().trim();
  }

  String _expenseInsights(List<Expense> expenses, String message) {
    if (expenses.isEmpty) {
      return 'No transactions yet. Log a few purchases and incomes, then ask for a spending insight.';
    }

    final DateTime now = DateTime.now();
    final ExpenseTotals month = _monthTotals(expenses, now);
    final List<Expense> monthRows = expenses.where((Expense e) {
      return e.date.year == now.year && e.date.month == now.month;
    }).toList();

    final Map<String, double> byCategory = <String, double>{};
    for (final Expense e in monthRows.where((Expense e) => !e.isIncome)) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    final List<MapEntry<String, double>> ranked = byCategory.entries.toList()
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) => b.value.compareTo(a.value));

    final StringBuffer buf = StringBuffer()
      ..writeln('${_monthName(now.month)} ${now.year} money snapshot:')
      ..writeln('• Income: ${_money(month.income)}')
      ..writeln('• Expenses: ${_money(month.expense)}')
      ..writeln('• Net: ${_money(month.net)}')
      ..writeln();

    if (ranked.isNotEmpty) {
      buf.writeln('Top categories:');
      for (final MapEntry<String, double> entry in ranked.take(5)) {
        final double pct = month.expense <= 0 ? 0 : (entry.value / month.expense) * 100;
        buf.writeln('• ${entry.key}: ${_money(entry.value)} (${pct.toStringAsFixed(0)}%)');
      }
      buf.writeln();
    }

    if (month.expense > month.income && month.income > 0) {
      buf.writeln('You are spending more than you earn this month. '
          'Trim the top category by 10–15% and delay one non-essential purchase.');
    } else if (month.net > 0) {
      buf.writeln('Solid month so far. Route part of the surplus (${_money(month.net * 0.2)}) '
          'toward a goal or emergency buffer.');
    } else if (month.income == 0) {
      buf.writeln('No income logged this month — add paydays so the picture stays accurate.');
    }

    if (message.toLowerCase().contains('save') || message.toLowerCase().contains('cut')) {
      if (ranked.isNotEmpty) {
        buf
          ..writeln()
          ..writeln(
            'Quick cut: reduce "${ranked.first.key}" by ${_money(ranked.first.value * 0.15)} '
            'this month (~15%).',
          );
      }
    }

    return buf.toString().trim();
  }

  String _journalReflection(List<JournalEntry> journal, String message) {
    if (journal.isEmpty) {
      return 'Your journal is empty. Try a 5-minute entry: what happened, how you felt, '
          'and one lesson. Then ask me to reflect with you.';
    }

    final List<JournalEntry> recent = List<JournalEntry>.from(journal)
      ..sort(
        (JournalEntry a, JournalEntry b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );

    final Map<String, int> moods = <String, int>{};
    for (final JournalEntry entry in recent.take(14)) {
      final String mood = (entry.mood ?? 'unspecified').toLowerCase();
      moods[mood] = (moods[mood] ?? 0) + 1;
    }
    final List<MapEntry<String, int>> moodRank = moods.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));

    final JournalEntry latest = recent.first;
    final StringBuffer buf = StringBuffer()
      ..writeln('Journal reflection:')
      ..writeln()
      ..writeln('Latest: "${latest.title}"${latest.mood != null ? ' (mood: ${latest.mood})' : ''}')
      ..writeln(_snippet(latest.content, 160))
      ..writeln();

    if (moodRank.isNotEmpty) {
      buf.writeln(
        'Recent mood pattern: ${moodRank.take(4).map((MapEntry<String, int> e) => '${e.key}×${e.value}').join(', ')}.',
      );
    }

    final String dominant = moodRank.isEmpty ? 'mixed' : moodRank.first.key;
    buf
      ..writeln()
      ..writeln(_moodAdvice(dominant))
      ..writeln()
      ..writeln('Prompt for tonight: What is one thing you want tomorrow-you to thank you for?');

    if (message.toLowerCase().contains('gratitude')) {
      buf.writeln('Gratitude lens: list 3 specifics from the last 48 hours — people, progress, comfort.');
    }

    return buf.toString().trim();
  }

  String _moodAdvice(String mood) {
    if (_matches(mood, const <String>['sad', 'down', 'anxious', 'stress', 'tired', 'overwhelm'])) {
      return 'Tone leans heavy. Keep today lighter: one meaningful task, a short walk, '
          'and a kind check-in with yourself — not a productivity marathon.';
    }
    if (_matches(mood, const <String>['happy', 'grateful', 'excited', 'good', 'calm', 'peace'])) {
      return 'Tone looks constructive. Capture what worked so you can repeat it tomorrow.';
    }
    return 'Mood looks mixed/neutral. Use a short body double or timer to start the next small action.';
  }

  String _translate(String message) {
    String text = message;
    String target = 'es';

    final RegExp toLang = RegExp(
      r'translate(?:\s+this)?(?:\s+to|\s+into)?\s+(spanish|french|german|urdu|arabic|english)\s*[:\-]?\s*(.*)$',
      caseSensitive: false,
    );
    final Match? match = toLang.firstMatch(message);
    if (match != null) {
      target = switch (match.group(1)!.toLowerCase()) {
        'spanish' => 'es',
        'french' => 'fr',
        'german' => 'de',
        'urdu' => 'ur',
        'arabic' => 'ar',
        _ => 'en',
      };
      text = (match.group(2) ?? '').trim();
    } else {
      final int colon = message.indexOf(':');
      if (colon > 0 && colon < message.length - 1) {
        text = message.substring(colon + 1).trim();
      }
    }

    if (text.isEmpty) {
      return 'Usage: translate to spanish: Hello, how are you?\n'
          'Supported: Spanish, French, German, Urdu, Arabic, English.';
    }

    final String translated = _simpleTranslate(text, target);
    return 'Translation ($target):\n$translated\n\n'
        'Note: this is a lightweight offline phrase dictionary — fine for common phrases, '
        'not a full linguistic model.';
  }

  String _simpleTranslate(String text, String target) {
    final Map<String, Map<String, String>> dict = <String, Map<String, String>>{
      'hello': <String, String>{
        'es': 'Hola',
        'fr': 'Bonjour',
        'de': 'Hallo',
        'ur': 'سلام',
        'ar': 'مرحبا',
        'en': 'Hello',
      },
      'how are you': <String, String>{
        'es': '¿Cómo estás?',
        'fr': 'Comment ça va?',
        'de': 'Wie geht es dir?',
        'ur': 'آپ کیسے ہیں؟',
        'ar': 'كيف حالك؟',
        'en': 'How are you?',
      },
      'thank you': <String, String>{
        'es': 'Gracias',
        'fr': 'Merci',
        'de': 'Danke',
        'ur': 'شکریہ',
        'ar': 'شكراً',
        'en': 'Thank you',
      },
      'good morning': <String, String>{
        'es': 'Buenos días',
        'fr': 'Bonjour',
        'de': 'Guten Morgen',
        'ur': 'صبح بخیر',
        'ar': 'صباح الخير',
        'en': 'Good morning',
      },
      'good night': <String, String>{
        'es': 'Buenas noches',
        'fr': 'Bonne nuit',
        'de': 'Gute Nacht',
        'ur': 'شب بخیر',
        'ar': 'تصبح على خير',
        'en': 'Good night',
      },
      'see you later': <String, String>{
        'es': 'Hasta luego',
        'fr': 'À plus tard',
        'de': 'Bis später',
        'ur': 'بعد میں ملتے ہیں',
        'ar': 'أراك لاحقاً',
        'en': 'See you later',
      },
      'i need help': <String, String>{
        'es': 'Necesito ayuda',
        'fr': "J'ai besoin d'aide",
        'de': 'Ich brauche Hilfe',
        'ur': 'مجھے مدد چاہیے',
        'ar': 'أحتاج مساعدة',
        'en': 'I need help',
      },
    };

    final String key = text.toLowerCase().trim().replaceAll(RegExp(r'[.!?]$'), '');
    if (dict.containsKey(key) && dict[key]!.containsKey(target)) {
      return dict[key]![target]!;
    }

    // Word-by-word fallback for short inputs.
    final List<String> words = text.split(RegExp(r'\s+'));
    final List<String> out = <String>[];
    for (final String word in words) {
      final String cleaned = word.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
      final String? mapped = dict[cleaned]?[target];
      out.add(mapped ?? word);
    }
    return out.join(' ');
  }

  String _brainstorm(String message, List<Note> notes, List<Goal> goals, List<Task> tasks) {
    String topic = message;
    for (final String prefix in <String>['brainstorm', 'ideas for', 'suggest ideas', 'come up with']) {
      final int idx = topic.toLowerCase().indexOf(prefix);
      if (idx >= 0) {
        topic = topic.substring(idx + prefix.length).trim();
        topic = topic.replaceFirst(RegExp(r'^[:\-\s]+'), '');
        break;
      }
    }
    if (topic.isEmpty) {
      topic = goals.isNotEmpty
          ? goals.first.title
          : (notes.isNotEmpty ? notes.first.title : 'personal productivity');
    }

    final List<String> relatedNotes = notes
        .where(
          (Note n) =>
              n.title.toLowerCase().contains(topic.toLowerCase()) ||
              n.content.toLowerCase().contains(topic.toLowerCase()) ||
              n.tags.any((String t) => topic.toLowerCase().contains(t.toLowerCase())),
        )
        .map((Note n) => n.title)
        .take(3)
        .toList();

    final StringBuffer buf = StringBuffer()
      ..writeln('Brainstorm: $topic')
      ..writeln()
      ..writeln('Angles to explore:')
      ..writeln('1. Minimum viable version you can finish in 25 minutes.')
      ..writeln('2. Ambitious version that would impress future-you in 90 days.')
      ..writeln('3. Collaboration twist — who could accelerate this?')
      ..writeln('4. Constraint remix — what if you only had \$0 / 1 hour / one tool?')
      ..writeln('5. Opposite approach — invert the usual assumption and list benefits.')
      ..writeln()
      ..writeln('Concrete next actions:')
      ..writeln('• Write a one-sentence success definition.')
      ..writeln('• List 5 options, pick 2, schedule one on your calendar.')
      ..writeln('• Turn the winner into a LifeOS task with a due date.');

    if (relatedNotes.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('Related notes to mine: ${relatedNotes.join(', ')}.');
    }
    final int open = tasks.where((Task t) => !t.isCompleted).length;
    if (open > 8) {
      buf.writeln('You already have $open open tasks — park this idea unless it beats your top 3 priorities.');
    }

    return buf.toString().trim();
  }

  String _overview(
    List<Task> tasks,
    List<Note> notes,
    List<Habit> habits,
    List<Expense> expenses,
    List<Goal> goals,
    List<JournalEntry> journal,
  ) {
    final int openTasks = tasks.where((Task t) => !t.isCompleted).length;
    final int doneTasks = tasks.where((Task t) => t.isCompleted).length;
    final int activeHabits = habits.where((Habit h) => h.isActive).length;
    final int activeGoals = goals.where((Goal g) => !g.isCompleted).length;
    final ExpenseTotals month = _monthTotals(expenses, DateTime.now());

    return '''
LifeOS overview:
• Tasks: $openTasks open / $doneTasks done
• Notes: ${notes.where((Note n) => !n.isArchived).length} active (${notes.where((Note n) => n.isPinned).length} pinned)
• Habits: $activeHabits active
• Goals: $activeGoals in progress
• Journal entries: ${journal.length}
• This month money: in ${_money(month.income)} / out ${_money(month.expense)} (net ${_money(month.net)})

Try: "plan my day", "prioritize tasks", "summarize notes", "habit tips", "expense insights", or "brainstorm: ...".
'''.trim();
  }

  String _generalChat(
    String message,
    List<Task> tasks,
    List<Habit> habits,
    List<Goal> goals,
  ) {
    final String lower = message.toLowerCase();
    if (_matches(lower, const <String>['hi', 'hello', 'hey', 'salaam', 'salam', 'good morning', 'good evening'])) {
      final int open = tasks.where((Task t) => !t.isCompleted).length;
      return 'Hey — I\'m your local LIFEOS assistant. '
          'You have $open open task${open == 1 ? '' : 's'} and ${habits.where((Habit h) => h.isActive).length} active habits. '
          'Ask me to plan your day, prioritize work, summarize notes, or reflect on your journal.';
    }
    if (_matches(lower, const <String>['help', 'what can you do', 'capabilities', 'commands'])) {
      return '''
I can help offline with:
• Planning & prioritization from your tasks/goals
• Note summaries and brainstorming
• Habit coaching from streak/XP data
• Expense insights for the current month
• Journal reflection prompts
• Simple phrase translation

Examples: "plan my day", "prioritize my tasks", "summarize notes", "habit tips", "expense insights", "translate to spanish: thank you".
'''.trim();
    }
    if (_matches(lower, const <String>['motiv', 'stuck', 'procrastin', 'can\'t start'])) {
      final Task? top = tasks.where((Task t) => !t.isCompleted).isEmpty
          ? null
          : (List<Task>.from(tasks.where((Task t) => !t.isCompleted))
                ..sort((Task a, Task b) => _taskScore(b).compareTo(_taskScore(a))))
              .first;
      return 'Start tiny. Set a 10-minute timer'
          '${top != null ? ' on "${top.title}"' : ''}, '
          'define the first physical action (open file / write title / send message), then move. '
          'Momentum beats motivation.';
    }

    final Goal? nearest = goals.where((Goal g) => !g.isCompleted).isEmpty
        ? null
        : (List<Goal>.from(goals.where((Goal g) => !g.isCompleted))
              ..sort((Goal a, Goal b) => a.targetDate.compareTo(b.targetDate)))
            .first;

    return 'I read that as a general question. '
        '${nearest != null ? 'Your nearest goal is "${nearest.title}" (${(nearest.progress * 100).round()}%). ' : ''}'
        'Tell me if you want planning, task priority, notes, habits, money, journal reflection, translation, or brainstorming — '
        'or say "overview" for a quick life snapshot.';
  }

  ExpenseTotals _monthTotals(List<Expense> expenses, DateTime month) {
    double income = 0;
    double expense = 0;
    for (final Expense e in expenses) {
      if (e.date.year != month.year || e.date.month != month.month) {
        continue;
      }
      if (e.isIncome) {
        income += e.amount;
      } else {
        expense += e.amount;
      }
    }
    return ExpenseTotals(income: income, expense: expense);
  }

  String _taskLine(Task task) {
    final String due = task.dueDate == null ? 'no due date' : 'due ${_fmtDate(task.dueDate!)}';
    return '${task.title} (${task.priority.label}, $due)';
  }

  String _snippet(String text, int max) {
    final String cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= max) {
      return cleaned;
    }
    return '${cleaned.substring(0, max - 1)}…';
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _money(double value) => '\$${value.toStringAsFixed(2)}';

  String _monthName(int month) {
    const List<String> names = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[month - 1];
  }
}

enum _Intent {
  planning,
  prioritize,
  noteSummary,
  habitTips,
  expenseInsights,
  journalReflection,
  translate,
  brainstorm,
  overview,
  general,
}
