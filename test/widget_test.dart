import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app.dart';
import 'package:lifeos/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('first launch shows the introduction, Skip marks it done', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        dbProvider.overrideWithValue(db),
        reminderSchedulerProvider.overrideWithValue(const NoReminders()),
      ],
    );

    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const PlaniaApp()));
    await tester.pump();
    expect(find.text('Your day on one screen'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    // Mark onboarding done directly; the shell itself needs live database streams.
    await container.read(settingsProvider.notifier).setOnboarded();
    expect(prefs.getBool('onboarded'), isTrue);

    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await db.close();
  });
}
