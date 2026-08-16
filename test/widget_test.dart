// Top-level smoke test: boots the real app root widget (as `main.dart`
// would), exercising app.dart's own startup path — permission request,
// launch-notification check, notification-tap subscription, and usage-streak
// tracking — on top of what the per-screen tests under test/screens/ already
// cover in isolation.
//
// _MyAppState's startup path now also calls
// ReviewPromptService.recordAppOpenAndMaybePromptReview(), which makes a
// real Hive write (recording today's usage) from inside a
// postFrameCallback, on flutter_test's fake clock — the same hazard
// documented in todo_set_edit_screen_save_test.dart and
// useTallTestViewport's doc comment. That write's own completion can end up
// waiting on a Timer that only ever fires on the real clock, so
// `Hive.deleteFromDisk()` in a normal tearDown can hang forever; this file
// is kept to a single test and uses tearDownWithoutClosingHive so nothing
// here ever needs Hive to close normally.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/app.dart';
import 'package:todo_reminder/providers/onboarding_providers.dart';

import 'support/hive_test_harness.dart';
import 'support/notification_channel_mocks.dart';
import 'support/pump_helpers.dart';

void main() {
  final harness = HiveTestHarness();

  setUp(() async {
    await harness.setUp();
    mockNotificationChannels();
  });

  tearDown(() {
    teardownMockNotificationChannels();
  });

  testWidgets('MyApp boots to the TodoSet list empty state without crashing', (
    tester,
  ) async {
    addTearDown(harness.tearDownWithoutClosingHive);

    // Onboarding is a separate, first-run-only screen (see
    // screens/onboarding_screen_test.dart) — mark it seen here so this
    // smoke test exercises the screen a returning user actually lands on.
    // Seeding via tester.runAsync(): a Hive write made in the plain test
    // zone before the first pumpWidget deadlocks pumpWidget once a screen
    // subscribes to a box's watch() stream (as TodoSetListScreen does).
    await tester.runAsync(() async {
      final seedContainer = ProviderContainer();
      await seedContainer.read(onboardingProvider.notifier).markSeen();
      seedContainer.dispose();
    });

    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await settle(tester);

    expect(find.text('右下の + からTodoセットを作成してください'), findsOneWidget);
  });
}
