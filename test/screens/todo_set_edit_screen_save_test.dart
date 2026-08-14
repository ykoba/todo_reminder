import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/data/todo_set_repository.dart';
import 'package:todo_reminder/notifications/notification_service.dart';
import 'package:todo_reminder/screens/todo_set_edit_screen.dart';

import '../support/hive_test_harness.dart';
import '../support/notification_channel_mocks.dart';
import '../support/pump_helpers.dart';

// Kept in its own file, with a single save-triggering test: in this test
// environment, the real Hive file write a tap on "保存" awaits doesn't
// reliably signal its own completion back to the awaiting code, and once
// that happens once in a test, flutter_test's end-of-test bookkeeping
// (which waits for a test's async work to fully quiesce before starting the
// next one) hangs indefinitely on every subsequent test sharing that
// process — even ones that don't touch Hive themselves. Isolating each
// save/delete-triggering scenario in its own file keeps that failure mode
// from cascading; see todo_set_edit_screen_edit_save_test.dart and
// todo_set_edit_screen_delete_test.dart for the others.
void main() {
  final harness = HiveTestHarness();

  setUp(() async {
    await harness.setUp();
    mockNotificationChannels();
    await NotificationService.instance.init();
  });

  tearDown(() async {
    teardownMockNotificationChannels();
    await harness.tearDown();
  });

  testWidgets('saving persists the name, drops blank items, and reflects the adjusted schedule', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute(builder: (_) => const TodoSetEditScreen(todoSetId: null)),
    );
    await settle(tester);

    await tester.enterText(find.byType(TextField).first, '保育園');
    await tester.tap(find.text('項目を追加'));
    await tester.tap(find.text('項目を追加'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(1), '連絡帳');
    // Second item row is left blank.
    await tester.tap(find.widgetWithText(FilterChip, '日'));
    await settle(tester);

    await tapAndSettle(tester, find.text('保存'));

    final saved = TodoSetRepository().getAll().single;
    expect(saved.name, '保育園');
    expect(saved.items.map((item) => item.label).toList(), ['連絡帳']);
    expect(saved.schedule.repeatDays, [1, 2, 3, 4, 5, 6]);
  });
}
