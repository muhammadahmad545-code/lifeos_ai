import 'dart:async';

import 'package:basalt/basalt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/app_lock.dart';
import '../services/background_sync.dart';
import '../services/quick_access.dart';
import 'calendar.dart';
import 'common.dart';
import 'focus.dart';
import 'home.dart';
import 'more.dart';
import 'notes.dart';
import 'tasks.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> with WidgetsBindingObserver {
  StreamSubscription<String>? _actions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Launcher shortcuts and the Quick Settings tile.
    _actions = QuickAccess.actions.listen((a) {
      QuickAccess.consumed();
      _open(a);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      unawaited(QuickAccess.installShortcuts());
      unawaited(ref.read(backgroundSyncProvider).catchUp());
      final a = await QuickAccess.takeAction();
      if (a != null) _open(a);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _actions?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back (maybe on a new day): post recurring entries and refresh the widget.
    if (state == AppLifecycleState.resumed) unawaited(ref.read(backgroundSyncProvider).catchUp());
  }

  void _open(String action) {
    if (!mounted) return;
    switch (action) {
      case QuickAccess.newTask:
        push(context, const TaskEditor());
      case QuickAccess.newNote:
        push(context, const NoteEditor());
      case QuickAccess.focus:
        final timer = ref.read(focusTimerProvider);
        if (!timer.active) timer.start();
        push(context, const FocusPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(backgroundSyncProvider);
    return BTabShell(
      controller: ref.watch(tabControllerProvider),
      tabs: [
        BTab(label: 'Home', icon: Icons.wb_sunny_outlined, selectedIcon: Icons.wb_sunny_rounded, builder: (_) => const HomePage()),
        BTab(label: 'Tasks', icon: Icons.check_circle_outline_rounded, selectedIcon: Icons.check_circle_rounded, builder: (_) => const TasksPage()),
        BTab(label: 'Notes', icon: Icons.sticky_note_2_outlined, selectedIcon: Icons.sticky_note_2_rounded, builder: (_) => const NotesPage()),
        BTab(label: 'Calendar', icon: Icons.calendar_today_outlined, selectedIcon: Icons.calendar_today_rounded, builder: (_) => const CalendarPage()),
        BTab(label: 'More', icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view_rounded, builder: (_) => const MorePage()),
      ],
    );
  }
}

/// Covers the app with a lock screen when the optional app lock is on: at start and when
/// coming back after more than [_grace] in the background.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  static const _grace = Duration(seconds: 30);

  late bool _locked = ref.read(settingsProvider).appLock;
  bool _authing = false;
  DateTime? _backgroundSince;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The system prompt itself pauses the app; ignore that.
    if (_authing) return;
    if (state == AppLifecycleState.paused) {
      _backgroundSince ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundSince;
      _backgroundSince = null;
      if (ref.read(settingsProvider).appLock && since != null && DateTime.now().difference(since) > _grace && !_locked) {
        setState(() => _locked = true);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_authing) return;
    if (!await AppLock.available()) {
      // The phone's screen lock was removed: the app lock cannot work, so turn it off
      // instead of locking the user out.
      await ref.read(settingsProvider.notifier).setAppLock(false);
      if (mounted) setState(() => _locked = false);
      return;
    }
    _authing = true;
    final ok = await AppLock.authenticate();
    _authing = false;
    _backgroundSince = null;
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.basalt;
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(Gap.xxl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      BIconTile(Icons.lock_outline_rounded, size: 64),
                      const SizedBox(height: Gap.xl),
                      Text('Plania is locked', style: BasaltType.title.copyWith(color: p.text)),
                      const SizedBox(height: Gap.sm),
                      Text('Use your fingerprint, face or phone PIN to continue.', textAlign: TextAlign.center, style: BasaltType.body.copyWith(color: p.textMuted)),
                      const SizedBox(height: Gap.xl),
                      BButton(label: 'Unlock', icon: Icons.fingerprint_rounded, onPressed: _unlock),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
