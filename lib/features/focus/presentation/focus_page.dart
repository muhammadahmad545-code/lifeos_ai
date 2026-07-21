import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/providers/feature_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/premium_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../domain/focus_session.dart';

enum _FocusMode { pomodoro, deepWork, shortBreak }

extension on _FocusMode {
  String get label => switch (this) {
        _FocusMode.pomodoro => 'Pomodoro',
        _FocusMode.deepWork => 'Deep Work',
        _FocusMode.shortBreak => 'Short Break',
      };

  int get defaultMinutes => switch (this) {
        _FocusMode.pomodoro => 25,
        _FocusMode.deepWork => 50,
        _FocusMode.shortBreak => 5,
      };

  String get storageName => switch (this) {
        _FocusMode.pomodoro => 'pomodoro',
        _FocusMode.deepWork => 'deep_work',
        _FocusMode.shortBreak => 'short_break',
      };
}

class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key});

  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage> {
  _FocusMode _mode = _FocusMode.pomodoro;
  int _durationMinutes = 25;
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;
  bool _ambientOn = false;
  DateTime? _startedAt;
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();

  String? get _userId => ref.read(authSessionProvider).valueOrNull?.id;

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _selectMode(_FocusMode mode) {
    if (_isRunning) {
      return;
    }
    setState(() {
      _mode = mode;
      _durationMinutes = mode.defaultMinutes;
      _remainingSeconds = mode.defaultMinutes * 60;
    });
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

  Future<void> _setAmbient(bool enabled) async {
    setState(() => _ambientOn = enabled);
    if (!enabled) {
      await _audioPlayer.stop();
      return;
    }
    try {
      // Soft rain loop (public domain sample). Requires internet the first time.
      await _audioPlayer.setUrl('https://cdn.pixabay.com/download/audio/2022/03/15/audio_c9a4a1d834.mp3');
      await _audioPlayer.setLoopMode(LoopMode.one);
      await _audioPlayer.setVolume(0.35);
      await _audioPlayer.play();
    } catch (_) {
      if (mounted) {
        setState(() => _ambientOn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ambient sound needs internet. Timer still works offline.')),
        );
      }
    }
  }

  void _start() {
    if (_isRunning) {
      return;
    }
    _startedAt ??= DateTime.now();
    setState(() => _isRunning = true);
    if (_ambientOn && !_audioPlayer.playing) {
      _audioPlayer.play();
    }
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
    _audioPlayer.pause();
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
    await _audioPlayer.stop();
    if (userId != null) {
      try {
        await ref.read(focusRepositoryProvider).saveSession(
              userId,
              FocusSession(
                id: '',
                durationMinutes: _durationMinutes,
                completedMinutes: _durationMinutes,
                mode: _mode.storageName,
                completed: true,
                startedAt: started,
                endedAt: DateTime.now(),
              ),
            );
      } catch (_) {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_mode.label} session complete! Great work.')),
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
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _FocusMode.values
                .map(
                  (_FocusMode mode) => ChoiceChip(
                    label: Text(mode.label),
                    selected: _mode == mode,
                    onSelected: _isRunning ? null : (_) => _selectMode(mode),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: <int>[15, 25, 45, 50, 60]
                .map(
                  (int m) => ChoiceChip(
                    label: Text('$m min'),
                    selected: _durationMinutes == m,
                    onSelected: _isRunning ? null : (_) => _selectDuration(m),
                  ),
                )
                .toList(),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ambient focus sound'),
            subtitle: const Text('Soft rain loop while you work'),
            value: _ambientOn,
            onChanged: _setAmbient,
          ),
          const SizedBox(height: 16),
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
