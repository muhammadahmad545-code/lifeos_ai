import 'dart:async';

import 'package:basalt/basalt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'providers.dart';
import 'services/quick_access.dart';
import 'services/reminders.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  QuickAccess.init();
  unawaited(BasaltUpdater.instance.start(owner: 'muhammadahmad545-code', repo: 'plania'));
  final prefs = await SharedPreferences.getInstance();
  await BasaltAppearanceController.load();
  final db = AppDatabase();
  await Reminders.instance.init(foreground: true);

  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        dbProvider.overrideWithValue(db),
      ],
      child: const PlaniaApp(),
    ),
  );

  // Re-register pending task reminders (covers imports, clock changes and upgrades from 1.x).
  unawaited(() async {
    try {
      await Reminders.instance.syncAll(await LifeRepo(db).allTasks());
    } catch (e) {
      debugPrint('reminder sync failed: $e');
    }
  }());
}
