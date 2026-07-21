import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/feature_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/premium_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../domain/focus_session.dart';

const List<int> _presetMinutes = <int>[15, 25, 45, 60];

class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key});

  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage> {
  int _durationMinutes = 25;
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;
  DateTime? _startedAt;
  Timer? _timer;

  String? get _userId => ref.read(authSessionProvider).valueOrNull?.id;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _selectDuration(int minutes) {
    if (_isRunning) {
      return;
    }
    setState(() {
      _durationMinutes = minutes;
      _remainingSeconds = minutes * 60;
    });
  }

  void _start() {
    if (_isRunning) {
      return;
    }
    _startedAt ??= DateTime.now();
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _isRunning = false;
        });
        _complete();
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _durationMinutes * 60;
      _startedAt = null;
    });
  }

  Future<void> _complete() async {
    final String? userId = _userId;
    final DateTime started = _startedAt ?? DateTime.now();
    _startedAt = null;
    if (userId != null) {
      try {
        await ref.read(focusRepositoryProvider).saveSession(
              userId,
              FocusSession(
                id: '',
                durationMinutes: _durationMinutes,
                completedMinutes: _durationMinutes,
                completed: true,
                startedAt: started,
                endedAt: DateTime.now(),
              ),
            );
      } catch (_) {
        // Local persistence best-effort; the countdown UI already reflects completion.
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Focus session complete! Great work.')),
      );
      setState(() => _remainingSeconds = _durationMinutes * 60);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<FocusStats> statsAsync = ref.watch(focusStatsProvider);
    final AsyncValue<List<FocusSession>> sessionsAsync = ref.watch(watchFocusSessionsProvider);
    final double progress = 1 - (_remainingSeconds / (_durationMinutes * 60));
    final int minutes = _remainingSeconds ~/ 60;
    final int seconds = _remainingSeconds % 60;

    return Scaffold(
      appBar: AppBar(title: const Text('Focus Timer')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: _presetMinutes
                .map(
                  (int m) => ChoiceChip(
                    label: Text('$m min'),
                    selected: _durationMinutes == m,
                    onSelected: _isRunning ? null : (_) => _selectDuration(m),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 32),
          Center(
            child: SizedBox(
              width: 240,
              height: 240,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: CircularProgressIndicator(
                      value: progress.clamp(0, 1),
                      strokeWidth: 10,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(_isRunning ? 'Focusing…' : (_remainingSeconds == _durationMinutes * 60 ? 'Ready' : 'Paused')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: _isRunning ? _pause : _start,
                icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                label: Text(_isRunning ? 'Pause' : (_remainingSeconds == _durationMinutes * 60 ? 'Start' : 'Resume')),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const SectionHeader(title: 'Stats'),
          const SizedBox(height: 12),
          statsAsync.when(
            data: (FocusStats stats) => Row(
              children: <Widget>[
                Expanded(
                  child: PremiumCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('${stats.totalMinutes}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const Text('Focus minutes'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PremiumCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('${stats.completedCount}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const Text('Completed sessions'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            loading: () => const LinearProgressIndicator(),
            error: (Object error, StackTrace stack) => Text('Error: $error'),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Recent sessions'),
          const SizedBox(height: 12),
          sessionsAsync.when(
            data: (List<FocusSession> sessions) {
              if (sessions.isEmpty) {
                return const Text('No sessions yet — finish your first Pomodoro above.');
              }
              return Column(
                children: sessions.take(5).map((FocusSession s) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(s.completed ? Icons.check_circle_outline : Icons.pause_circle_outline),
                      title: Text('${s.completedMinutes} min · ${s.mode}'),
                      subtitle: Text(s.startedAt.toLocal().toString().split('.').first),
                      trailing: s.completed ? const Chip(label: Text('done')) : const Chip(label: Text('partial')),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stack) => Text('Error: $error'),
          ),
        ],
      ),
    );
  }
}
