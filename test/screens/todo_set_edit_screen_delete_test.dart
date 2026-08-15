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
// this file only exercises the "削除" tap without waiting on its result —
// what's actually removed is covered by todo_set_repository_test.dart.
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

  testWidgets('confirming the delete dialog does not throw', (tester) async {
    addTearDown(harness.tearDownWithoutClosingHive);
    await tester.runAsync(
      () => TodoSetRepository().save(buildTodoSet(id: 'a')),
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

    await tester.tap(find.byIcon(Icons.delete_outline));
    await settle(tester);
    expect(find.text('このセットを削除しますか？'), findsOneWidget);

    // Not awaiting the delete's own completion — see the file comment above.
    await tester.tap(find.text('削除'));
    await tester.pump();
  });
}
