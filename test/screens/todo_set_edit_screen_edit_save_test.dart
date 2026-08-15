import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/data/todo_set_repository.dart';
import 'package:todo_reminder/notifications/notification_service.dart';
import 'package:todo_reminder/screens/todo_set_edit_screen.dart';

import '../support/fixtures.dart';
import '../support/hive_test_harness.dart';
import '../support/notification_channel_mocks.dart';
import '../support/pump_helpers.dart';

// See the comment at the top of todo_set_edit_screen_save_test.dart for why
// this file only exercises the "保存" tap without waiting on its result —
// what's actually persisted is covered by todo_set_repository_test.dart.
void main() {
  final harness = HiveTestHarness();

  setUp(() async {
    await harness.setUp();
    mockNotificationChannels();
    await NotificationService.instance.init();
  });

  tearDown(() {
    teardownMockNotificationChannels();
  });

  testWidgets('toggling the enabled switch and saving does not throw', (
    tester,
  ) async {
    addTearDown(harness.tearDownWithoutClosingHive);
    useTallTestViewport(tester);
    await tester.runAsync(
      () => TodoSetRepository().save(
        buildTodoSet(
          id: 'a',
          name: '保育園',
          items: [buildTodoItem(label: '連絡帳', sortOrder: 0)],
          schedule: buildSchedule(hour: 7, minute: 30, repeatDays: [1, 2, 3]),
          isEnabled: false,
        ),
      ),
    );

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
      MaterialPageRoute(
        builder: (_) => const TodoSetEditScreen(todoSetId: 'a'),
      ),
    );
    await settle(tester);

    await tester.tap(find.byType(SwitchListTile));
    await settle(tester);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );

    // Not awaiting the save's own completion — see the file comment above.
    await tester.tap(find.text('保存'));
    await tester.pump();
    // scheduleForTodoSet()'s own call pattern (cancel-then-zonedSchedule per
    // weekday, skip when disabled/empty, etc.) is covered exhaustively and
    // reliably in notifications/notification_service_test.dart; it isn't
    // re-asserted here.
  });
}
