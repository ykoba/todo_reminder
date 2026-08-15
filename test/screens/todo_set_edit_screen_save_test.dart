import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/notifications/notification_service.dart';
import 'package:todo_reminder/screens/todo_set_edit_screen.dart';
import 'package:todo_reminder/utils/todo_set_icons.dart';

import '../support/hive_test_harness.dart';
import '../support/notification_channel_mocks.dart';
import '../support/pump_helpers.dart';

// A tap on "保存" triggers a real Hive disk write from inside the widget's
// onPressed callback, on flutter_test's fake clock. That write's own
// completion can end up waiting on a Timer that only ever fires on the real
// clock, so it may never resolve — meaning any assertion made after the tap
// (on the saved data, or even on whether the screen navigated away) risks
// hanging forever, and so does this file's own `tearDown` if it tries to
// close Hive normally (see HiveTestHarness.tearDownWithoutClosingHive's doc
// comment). What's actually persisted — including this set's icon — is
// covered instead by todo_set_repository_test.dart's dedicated (non-widget)
// tests. This file only exercises the tap itself, without waiting on its
// result, and is kept to this single test so nothing else in this process
// ever reopens a box against the now-unrecoverable Hive instance.
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
    'saving with a name, a blank item row, an adjusted schedule, and a chosen icon does not throw',
    (tester) async {
      addTearDown(harness.tearDownWithoutClosingHive);
      useTallTestViewport(tester);
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
          builder: (_) => const TodoSetEditScreen(todoSetId: null),
        ),
      );
      await settle(tester);

      await tester.enterText(find.byType(TextField).first, '保育園');
      await tester.tap(find.text('項目を追加'));
      await tester.tap(find.text('項目を追加'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).at(1), '連絡帳');
      // Second item row is left blank.
      await tester.tap(find.widgetWithText(FilterChip, '日'));
      await tester.tap(find.byIcon(todoSetIcons['school']!));
      await settle(tester);

      // Not awaiting the save's own completion — see the file comment above
      // for why. A single tap + pump is enough to exercise _save()'s
      // synchronous item-filtering/schedule-building logic without hanging
      // on its real Hive write.
      await tester.tap(find.text('保存'));
      await tester.pump();
    },
  );
}
