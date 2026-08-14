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

// This file covers everything about TodoSetEditScreen that doesn't require
// a real Hive write to complete (validation, local item-list editing,
// pre-fill display, dismissing the delete dialog). Scenarios that tap
// "保存"/"削除" and need that write to actually land each get their own
// dedicated file — see todo_set_edit_screen_save_test.dart,
// todo_set_edit_screen_edit_save_test.dart, and
// todo_set_edit_screen_delete_test.dart, plus the comment in
// todo_set_edit_screen_save_test.dart explaining why.
void main() {
  final harness = HiveTestHarness();

  setUp(() async {
    await harness.setUp();
    mockNotificationChannels();
    // scheduleForTodoSet() (triggered by saving) needs tz.local, which is
    // only set up by NotificationService.init() — normally called once from
    // main() at app startup, so tests must call it themselves.
    await NotificationService.instance.init();
  });

  tearDown(() async {
    teardownMockNotificationChannels();
    await harness.tearDown();
  });

  /// Pushes [TodoSetEditScreen] onto a real navigation stack (rather than
  /// making it the app's only route) so that the screen's own
  /// `Navigator.pop()` after save/delete has somewhere to go back to, just
  /// like when it's opened from [TodoSetListScreen].
  Future<void> pumpEdit(WidgetTester tester, {String? todoSetId}) async {
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
      MaterialPageRoute(builder: (_) => TodoSetEditScreen(todoSetId: todoSetId)),
    );
    await settle(tester);
  }

  group('creating a new set', () {
    testWidgets('shows a validation message and saves nothing when the name is empty', (tester) async {
      await pumpEdit(tester);

      await tester.tap(find.text('保存'));
      await tester.pump();

      expect(find.text('セット名を入力してください'), findsOneWidget);
      expect(TodoSetRepository().getAll(), isEmpty);
    });

    testWidgets('tapping the close icon removes that item row', (tester) async {
      await pumpEdit(tester);
      await tester.tap(find.text('項目を追加'));
      await tester.tap(find.text('項目を追加'));
      await settle(tester);
      expect(find.byType(TextField), findsNWidgets(3)); // name + 2 items

      await tester.tap(find.byIcon(Icons.close).first);
      await settle(tester);

      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('has no delete button', (tester) async {
      await pumpEdit(tester);

      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });
  });

  group('editing an existing set', () {
    Future<void> seedAndPump(WidgetTester tester) async {
      // Seeding via tester.runAsync(): a Hive write made in the plain test
      // zone before the first pumpWidget has intermittently left later
      // pumpAndSettle() calls in the same test unable to complete.
      await tester.runAsync(() => TodoSetRepository().save(buildTodoSet(
            id: 'a',
            name: '保育園',
            items: [buildTodoItem(label: '連絡帳', sortOrder: 0)],
            schedule: buildSchedule(hour: 7, minute: 30, repeatDays: [1, 2, 3]),
            isEnabled: false,
          )));
      await pumpEdit(tester, todoSetId: 'a');
    }

    testWidgets('pre-fills the name, items, time, weekdays, and enabled switch', (tester) async {
      await seedAndPump(tester);

      expect(find.text('保育園'), findsOneWidget);
      expect(find.text('連絡帳'), findsOneWidget);
      expect(find.text('07:30'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
      expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, '月')).selected, isTrue);
      expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, '木')).selected, isFalse);
    });

    testWidgets('cancelling the delete confirmation keeps the set', (tester) async {
      await seedAndPump(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await settle(tester);
      await tester.tap(find.text('キャンセル'));
      await settle(tester);

      expect(TodoSetRepository().getById('a'), isNotNull);
      expect(find.byType(TodoSetEditScreen), findsOneWidget);
    });
  });
}
