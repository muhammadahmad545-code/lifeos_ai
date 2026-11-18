import 'dart:async';

import 'package:basalt/basalt.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/database.dart';
import 'data/repo.dart';
import 'services/reminders.dart';
import 'services/settings.dart';

export 'data/database.dart';
export 'data/repo.dart';
export 'services/settings.dart';

final dbProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('dbProvider is set in main()'));

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) => Reminders.instance);

final repoProvider = Provider<LifeRepo>((ref) => LifeRepo(ref.watch(dbProvider), ref.watch(reminderSchedulerProvider)));

final tasksProvider = StreamProvider<List<TaskRow>>((ref) => ref.watch(repoProvider).watchTasks());
final notesProvider = StreamProvider<List<NoteRow>>((ref) => ref.watch(repoProvider).watchNotes());
final eventsProvider = StreamProvider<List<CalendarEventRow>>((ref) => ref.watch(repoProvider).watchEvents());
final habitsProvider = StreamProvider<List<HabitRow>>((ref) => ref.watch(repoProvider).watchHabits());
final habitLogsProvider = StreamProvider<List<HabitLogRow>>((ref) => ref.watch(repoProvider).watchHabitLogs());
final journalProvider = StreamProvider<List<JournalEntryRow>>((ref) => ref.watch(repoProvider).watchJournal());
final expensesProvider = StreamProvider<List<ExpenseRow>>((ref) => ref.watch(repoProvider).watchExpenses());
final budgetsProvider = StreamProvider<List<BudgetRow>>((ref) => ref.watch(repoProvider).watchBudgets());
final goalsProvider = StreamProvider<List<GoalRow>>((ref) => ref.watch(repoProvider).watchGoals());
final focusSessionsProvider = StreamProvider<List<FocusSessionRow>>((ref) => ref.watch(repoProvider).watchFocus());

/// Habit id -> set of done day keys.
final habitDaysProvider = Provider<Map<String, Set<String>>>((ref) {
  final logs = ref.watch(habitLogsProvider).valueOrNull ?? const <HabitLogRow>[];
  final map = <String, Set<String>>{};
  for (final l in logs) {
    map.putIfAbsent(l.habitId, () => <String>{}).add(l.day);
  }
  return map;
});

/// Lets cards on Home switch the bottom tab.
final tabControllerProvider = Provider<BTabController>((ref) {
  final c = BTabController();
  ref.onDispose(c.dispose);
  return c;
});

final focusTimerProvider = ChangeNotifierProvider<FocusTimer>(
  (ref) => FocusTimer(ref.watch(repoProvider), ref.watch(prefsProvider), Reminders.instance),
);

/// Pomodoro-style timer. It keeps an absolute end time (persisted), so it survives the app
/// being backgrounded or killed; a notification is scheduled for the end.
class FocusTimer extends ChangeNotifier {
  FocusTimer(this._repo, this._prefs, this._reminders) {
    _restore();
  }

  final LifeRepo _repo;
  final SharedPreferences _prefs;
  final Reminders? _reminders;

  static const _kEnd = 'focus_end';
  static const _kMinutes = 'focus_minutes';
  static const _kStarted = 'focus_started';
  static const _kPaused = 'focus_paused_ms';

  int minutes = 25;
  DateTime? _endAt;
  Duration? _pausedRemaining;
  DateTime? _startedAt;
  Timer? _ticker;

  /// Set when a session finishes, so the screen can say so.
  DateTime? lastCompletedAt;

  bool get running => _endAt != null;
  bool get paused => _pausedRemaining != null;
  bool get active => running || paused;

  Duration get total => Duration(minutes: minutes);

  Duration get remaining {
    if (_endAt != null) {
      final r = _endAt!.difference(DateTime.now());
      return r.isNegative ? Duration.zero : r;
    }
    return _pausedRemaining ?? total;
  }

  double get progress {
    final t = total.inMilliseconds;
    if (t <= 0) return 0;
    return (1 - remaining.inMilliseconds / t).clamp(0.0, 1.0);
  }

  void setMinutes(int m) {
    if (active || m < 1) return;
    minutes = m;
    notifyListeners();
  }

  void start() {
    final now = DateTime.now();
    _startedAt ??= now;
    _endAt = now.add(_pausedRemaining ?? total);
    _pausedRemaining = null;
    lastCompletedAt = null;
    unawaited(_reminders?.scheduleFocusEnd(_endAt!, minutes));
    _persist();
    _startTicker();
    notifyListeners();
  }

  void pause() {
    if (!running) return;
    _pausedRemaining = remaining;
    _endAt = null;
    _ticker?.cancel();
    unawaited(_reminders?.cancelFocusEnd());
    _persist();
    notifyListeners();
  }

  /// Ends the session early. Anything of a minute or more is still recorded.
  Future<void> stop() async {
    final started = _startedAt;
    final done = (total - remaining).inMinutes;
    _reset();
    unawaited(_reminders?.cancelFocusEnd());
    if (started != null && done >= 1) {
      await _repo.addFocusSession(
        plannedMinutes: minutes,
        minutes: done,
        completed: false,
        startedAt: started,
        endedAt: DateTime.now(),
      );
    }
  }

  Future<void> _complete() async {
    final started = _startedAt ?? DateTime.now().subtract(total);
    final end = _endAt ?? DateTime.now();
    _reset();
    lastCompletedAt = DateTime.now();
    notifyListeners();
    await _repo.addFocusSession(
      plannedMinutes: minutes,
      minutes: minutes,
      completed: true,
      startedAt: started,
      endedAt: end,
    );
  }

  void _reset() {
    _ticker?.cancel();
    _endAt = null;
    _pausedRemaining = null;
    _startedAt = null;
    _persist();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (running && remaining == Duration.zero) {
        unawaited(_complete());
      } else {
        notifyListeners();
      }
    });
  }

  void _persist() {
    unawaited(() async {
      await _prefs.setInt(_kMinutes, minutes);
      if (_endAt != null) {
        await _prefs.setInt(_kEnd, _endAt!.millisecondsSinceEpoch);
      } else {
        await _prefs.remove(_kEnd);
      }
      if (_pausedRemaining != null) {
        await _prefs.setInt(_kPaused, _pausedRemaining!.inMilliseconds);
      } else {
        await _prefs.remove(_kPaused);
      }
      if (_startedAt != null) {
        await _prefs.setInt(_kStarted, _startedAt!.millisecondsSinceEpoch);
      } else {
        await _prefs.remove(_kStarted);
      }
    }());
  }

  void _restore() {
    minutes = _prefs.getInt(_kMinutes) ?? 25;
    final started = _prefs.getInt(_kStarted);
    _startedAt = started == null ? null : DateTime.fromMillisecondsSinceEpoch(started);
    final paused = _prefs.getInt(_kPaused);
    final end = _prefs.getInt(_kEnd);
    if (paused != null) {
      _pausedRemaining = Duration(milliseconds: paused);
    } else if (end != null) {
      _endAt = DateTime.fromMillisecondsSinceEpoch(end);
      if (_endAt!.isAfter(DateTime.now())) {
        _startTicker();
      } else {
        // Finished while the app was closed.
        unawaited(_complete());
      }
    } else {
      _startedAt = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// Small helper: the current value of a list stream, or empty while loading.
extension ListValue<T> on AsyncValue<List<T>> {
  List<T> get list => valueOrNull ?? <T>[];
}

