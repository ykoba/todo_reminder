import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/data/todo_set_repository.dart';
import 'package:todo_reminder/notifications/notification_service.dart';
import 'package:todo_reminder/screens/todo_set_list_screen.dart';

import '../support/fixtures.dart';
import '../support/hive_test_harness.dart';
import '../support/notification_channel_mocks.dart';
import '../support/pump_helpers.dart';

// Swiping a row open and tapping its revealed delete button triggers
// _deleteWithUndo(), which awaits a real Hive write (TodoSetRepository.delete)
// and a notification-channel call (NotificationService.cancelForTodoSet) from
// inside the SlidableAction's onPressed callback. Per the same fake-clock-
// Timer issue documented in todo_set_edit_screen_save_test.dart, that write's
// completion may never resolve inside this test's pump cycle, so this file
// only exercises the swipe-then-tap gesture itself without waiting on its
// result. What's actually removed (and what saving a set back via the undo
// action actually persists) is covered instead by todo_set_repository_test.dart
// and notification_service_test.dart. Kept to a single test so nothing else
// in this process ever reopens a box against the now-unrecoverable Hive
// instance.
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

  testWidgets(
    'swiping a row open and tapping the delete button does not throw',
    (tester) async {
      addTearDown(harness.tearDownWithoutClosingHive);
      await tester.runAsync(
        () => TodoSetRepository().save(buildTodoSet(id: 'a', name: 'A')),
      );

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: TodoSetListScreen())),
      );
      await settle(tester);

      await tester.drag(find.text('A'), const Offset(-300, 0));
      await settle(tester);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      // Not awaiting the delete's own completion — see the file comment above.
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
    },
  );
}
