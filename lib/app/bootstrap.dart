import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/providers/providers.dart';
import '../core/services/firebase_bootstrap_service.dart';
import '../core/services/settings_service.dart';
import 'lifeos_app.dart';

Future<void> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<dynamic>(SettingsService.boxName);
  await FirebaseBootstrapService().initialize();

  final ProviderContainer container = ProviderContainer();
  await container.read(authRepositoryProvider).restoreSession();
  await container.read(localNotificationServiceProvider).initialize();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const LifeOSApp(),
    ),
  );
}
