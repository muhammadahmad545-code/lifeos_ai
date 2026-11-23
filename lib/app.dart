import 'package:basalt/basalt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'ui/shell.dart';

const BasaltAccent kAccent = BasaltAccent.violet;

class PlaniaApp extends ConsumerWidget {
  const PlaniaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp(
      title: 'Plania',
      debugShowCheckedModeBanner: false,
      theme: basaltTheme(Brightness.light, kAccent),
      darkTheme: basaltTheme(Brightness.dark, kAccent),
      themeMode: mode,
      // The lock sits above the navigator so it also covers pushed screens.
      builder: (context, child) => AppLockGate(child: child ?? const SizedBox.shrink()),
      home: const RootGate(),
    );
  }
}

/// First run shows the introduction; after that the app opens straight into Home.
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(settingsProvider.select((s) => s.onboarded));
    if (!onboarded) {
      return BOnboarding(
        appName: 'Plania',
        pages: const [
          BOnboardingPage(
            icon: Icons.wb_sunny_outlined,
            title: 'Your day on one screen',
            body: 'Home shows what is due, your habits, today’s events and your focus time.',
          ),
          BOnboardingPage(
            icon: Icons.checklist_rounded,
            title: 'Tasks, notes and calendar',
            body: 'Due dates, priorities, repeats and reminders that really fire. Notes with checklists. A month calendar.',
          ),
          BOnboardingPage(
            icon: Icons.insights_outlined,
            title: 'Habits, money and goals',
            body: 'Streaks, a journal, monthly spending with budgets, goals with milestones and a focus timer.',
          ),
          BOnboardingPage(
            icon: Icons.lock_outline_rounded,
            title: 'Private by design',
            body: 'No account and no cloud. Everything stays on this phone. Back it up to a file whenever you like.',
          ),
        ],
        onDone: () => ref.read(settingsProvider.notifier).setOnboarded(),
      );
    }
    return const HomeShell();
  }
}
