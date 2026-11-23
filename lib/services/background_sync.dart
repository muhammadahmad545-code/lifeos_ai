import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/dates.dart';
import '../logic/today_widget.dart';
import '../providers.dart';
import 'quick_access.dart';

/// Keeps the "Today" widget in step with the data and posts recurring expenses on time.
///
/// The widget is refreshed whenever tasks, habits, events or the app lock change (debounced,
/// so a burst of edits sends one update) and again just after midnight. Recurring entries are
/// posted at midnight while the app runs; [HomeShell] also posts them on start and resume.
final backgroundSyncProvider = Provider<BackgroundSync>((ref) {
  final sync = BackgroundSync(ref);
  ref.onDispose(sync.dispose);
  return sync;
});

class BackgroundSync {
  BackgroundSync(this._ref) {
    void changed(Object? _, Object? _) => scheduleWidget();
    _ref.listen(tasksProvider, changed);
    _ref.listen(habitsProvider, changed);
    _ref.listen(habitLogsProvider, changed);
    _ref.listen(eventsProvider, changed);
    _ref.listen(settingsProvider.select((s) => s.appLock), changed);
    scheduleWidget();
    _armMidnight();
  }

  final Ref _ref;
  Timer? _debounce;
  Timer? _midnight;

  static const debounce = Duration(milliseconds: 800);

  void scheduleWidget() {
    _debounce?.cancel();
    _debounce = Timer(debounce, pushWidget);
  }

  Future<void> pushWidget() async {
    final tasks = _ref.read(tasksProvider).valueOrNull;
    final habits = _ref.read(habitsProvider).valueOrNull;
    final logs = _ref.read(habitLogsProvider).valueOrNull;
    final events = _ref.read(eventsProvider).valueOrNull;
    // Still loading: the listeners fire again once the data is there.
    if (tasks == null || habits == null || logs == null || events == null) return;
    await QuickAccess.updateWidget(
      todayWidgetData(
        tasks: tasks,
        habits: habits,
        habitDays: _ref.read(habitDaysProvider),
        events: events,
        now: DateTime.now(),
        locked: _ref.read(settingsProvider).appLock,
      ),
    );
  }

  /// Posts recurring entries that are due, then refreshes the widget.
  Future<void> catchUp() async {
    try {
      await _ref.read(repoProvider).postDueRecurring();
    } catch (_) {}
    scheduleWidget();
  }

  void _armMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    final next = addDays(dateOnly(now), 1).add(const Duration(seconds: 2));
    _midnight = Timer(next.difference(now), () {
      unawaited(catchUp());
      _armMidnight();
    });
  }

  void dispose() {
    _debounce?.cancel();
    _midnight?.cancel();
  }
}
