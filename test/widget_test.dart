// Top-level smoke test: boots the real app root widget (as `main.dart`
// would), exercising app.dart's own startup path — permission request,
// launch-notification check, and notification-tap subscription — on top of
// what the per-screen tests under test/screens/ already cover in isolation.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/app.dart';

import 'support/hive_test_harness.dart';
import 'support/notification_channel_mocks.dart';
import 'support/pump_helpers.dart';

void main() {
  final harness = HiveTestHarness();

  setUp(() async {
    await harness.setUp();
    mockNotificationChannels();
  });

  tearDown(() async {
    teardownMockNotificationChannels();
    await harness.tearDown();
  });

  testWidgets('MyApp boots to the TodoSet list empty state without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await settle(tester);

    expect(find.text('右下の + からTodoセットを作成してください'), findsOneWidget);
  });
}
