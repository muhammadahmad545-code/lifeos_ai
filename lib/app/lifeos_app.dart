import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/providers/providers.dart';
import '../core/theme/lifeos_theme.dart';

class LifeOSApp extends ConsumerWidget {
  const LifeOSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      theme: LifeOSTheme.light(),
      darkTheme: LifeOSTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
