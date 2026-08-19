import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/data/todo_set_repository.dart';
import 'package:todo_reminder/notifications/notification_service.dart';
import 'package:todo_reminder/screens/todo_set_edit_screen.dart';
import 'package:todo_reminder/utils/todo_set_icons.dart';

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
        builder: (_) => TodoSetEditScreen(todoSetId: todoSetId),
      ),
    );
    await settle(tester);
  }

  Color? avatarBackgroundFor(WidgetTester tester, IconData icon) {
    final avatarFinder = find.ancestor(
      of: find.byIcon(icon),
      matching: find.byType(CircleAvatar),
    );
    return tester.widget<CircleAvatar>(avatarFinder).backgroundColor;
  }

  group('creating a new set', () {
    testWidgets(
      'shows a validation message and saves nothing when the name is empty',
      (tester) async {
        await pumpEdit(tester);

        await tester.tap(find.text('保存'));
        await tester.pump();

        expect(find.text('セット名を入力してください'), findsOneWidget);
        expect(TodoSetRepository().getAll(), isEmpty);
      },
    );

    testWidgets(
      'shows a validation message and saves nothing when there are no items',
      (tester) async {
        await pumpEdit(tester);

        await tester.enterText(find.byType(TextField).first, '保育園');
        await tester.tap(find.text('保存'));
        await tester.pump();

        expect(find.text('持ち物を1つ以上入力してください'), findsOneWidget);
        expect(TodoSetRepository().getAll(), isEmpty);
      },
    );

    testWidgets(
      'shows a validation message when the only item row is left blank',
      (tester) async {
        await pumpEdit(tester);

        await tester.enterText(find.byType(TextField).first, '保育園');
        await tester.tap(find.text('持ち物を追加'));
        await settle(tester);
        // The added item row is left blank.
        await tester.tap(find.text('保存'));
        await tester.pump();

        expect(find.text('持ち物を1つ以上入力してください'), findsOneWidget);
        expect(TodoSetRepository().getAll(), isEmpty);
      },
    );

    testWidgets('tapping the close icon removes that item row', (tester) async {
      await pumpEdit(tester);
      await tester.tap(find.text('持ち物を追加'));
      await tester.tap(find.text('持ち物を追加'));
      await settle(tester);
      expect(find.byType(TextField), findsNWidgets(3)); // name + 2 items

      await tester.tap(find.byIcon(Icons.close).first);
      await settle(tester);

      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets(
      'submitting a row focuses the topmost still-blank row instead of '
      'always adding a new one',
      (tester) async {
        await pumpEdit(tester);
        await tester.enterText(find.byType(TextField).first, 'テストセット');

        await tester.tap(find.text('持ち物を追加'));
        await settle(tester);
        await tester.tap(find.text('持ち物を追加'));
        await settle(tester);
        await tester.tap(find.text('持ち物を追加'));
        await settle(tester);
        expect(find.byType(TextField), findsNWidgets(4)); // name + 3 items

        // Fill only the last item row, leaving the first two blank.
        await tester.enterText(find.byType(TextField).at(3), '石鹸');
        await settle(tester);

        // Submitting from the last (filled) row should jump focus to the
        // topmost blank row rather than appending a 4th row.
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await settle(tester);
        expect(find.byType(TextField), findsNWidgets(4)); // unchanged

        tester.testTextInput.enterText('シャンプー');
        await settle(tester);
        expect(
          tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
          'シャンプー',
        );
        // The second (still-blank) row is untouched.
        expect(
          tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text,
          isEmpty,
        );
      },
    );

    testWidgets(
      'submitting a row adds a new one only once every row already has text',
      (tester) async {
        await pumpEdit(tester);
        await tester.enterText(find.byType(TextField).first, 'テストセット');

        await tester.tap(find.text('持ち物を追加'));
        await settle(tester);
        expect(find.byType(TextField), findsNWidgets(2)); // name + 1 item

        await tester.enterText(find.byType(TextField).at(1), 'タオル');
        await settle(tester);

        await tester.testTextInput.receiveAction(TextInputAction.next);
        await settle(tester);

        expect(find.byType(TextField), findsNWidgets(3)); // a new row appended
        expect(
          tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text,
          isEmpty,
        );
      },
    );

    testWidgets('has no delete button', (tester) async {
      await pumpEdit(tester);

      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets(
      'limits the set name to 20 characters regardless of half/full-width',
      (tester) async {
        await pumpEdit(tester);

        await tester.enterText(find.byType(TextField).first, 'あ' * 25);
        await settle(tester);

        final nameField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        expect(nameField.controller!.text.length, 20);
      },
    );

    testWidgets(
      'offers all 20 icon choices with "checklist" selected by default',
      (tester) async {
        await pumpEdit(tester);

        for (final icon in todoSetIcons.values) {
          expect(find.byIcon(icon), findsOneWidget);
        }
        final selectedColor = avatarBackgroundFor(
          tester,
          todoSetIcons[defaultTodoSetIconKey]!,
        );
        final unselectedColor = avatarBackgroundFor(
          tester,
          todoSetIcons['school']!,
        );
        expect(selectedColor, isNot(unselectedColor));
      },
    );

    testWidgets('tapping a different icon selects it', (tester) async {
      await pumpEdit(tester);
      final defaultColor = avatarBackgroundFor(
        tester,
        todoSetIcons[defaultTodoSetIconKey]!,
      );

      await tester.tap(find.byIcon(todoSetIcons['school']!));
      await settle(tester);

      expect(
        avatarBackgroundFor(tester, todoSetIcons['school']!),
        defaultColor,
      );
      expect(
        avatarBackgroundFor(tester, todoSetIcons[defaultTodoSetIconKey]!),
        isNot(defaultColor),
      );
    });
  });

  group('editing an existing set', () {
    Future<void> seedAndPump(WidgetTester tester) async {
      // Seeding via tester.runAsync(): a Hive write made in the plain test
      // zone before the first pumpWidget has intermittently left later
      // pumpAndSettle() calls in the same test unable to complete.
      await tester.runAsync(
        () => TodoSetRepository().save(
          buildTodoSet(
            id: 'a',
            name: '保育園',
            items: [buildTodoItem(label: '連絡帳', sortOrder: 0)],
            schedule: buildSchedule(hour: 7, minute: 30, repeatDays: [1, 2, 3]),
            isEnabled: false,
            icon: 'school',
          ),
        ),
      );
      await pumpEdit(tester, todoSetId: 'a');
    }

    testWidgets(
      'pre-fills the name, items, time, weekdays, enabled switch, and icon',
      (tester) async {
        await seedAndPump(tester);

        expect(find.text('保育園'), findsOneWidget);
        expect(find.text('連絡帳'), findsOneWidget);
        expect(find.text('07:30'), findsOneWidget);
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isFalse,
        );
        expect(
          tester
              .widget<FilterChip>(find.widgetWithText(FilterChip, '月'))
              .selected,
          isTrue,
        );
        expect(
          tester
              .widget<FilterChip>(find.widgetWithText(FilterChip, '木'))
              .selected,
          isFalse,
        );
        // The seeded set's icon ('school') should be the selected one, visibly
        // different from an unselected choice.
        expect(
          avatarBackgroundFor(tester, todoSetIcons['school']!),
          isNot(avatarBackgroundFor(tester, todoSetIcons['pets']!)),
        );
      },
    );

    testWidgets('cancelling the delete confirmation keeps the set', (
      tester,
    ) async {
      await seedAndPump(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await settle(tester);
      await tester.tap(find.text('キャンセル'));
      await settle(tester);

      expect(TodoSetRepository().getById('a'), isNotNull);
      expect(find.byType(TodoSetEditScreen), findsOneWidget);
    });

    testWidgets('pre-fills 隔週 when the seeded schedule has intervalWeeks 2', (
      tester,
    ) async {
      await tester.runAsync(
        () => TodoSetRepository().save(
          buildTodoSet(
            id: 'b',
            items: [buildTodoItem(sortOrder: 0)],
            schedule: buildSchedule(repeatDays: [1], intervalWeeks: 2),
          ),
        ),
      );
      await pumpEdit(tester, todoSetId: 'b');

      expect(
        tester
            .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
            .selected,
        {2},
      );
    });
  });

  group('notification times and frequency', () {
    testWidgets('a new set starts with a single default time and 毎週 selected', (
      tester,
    ) async {
      await pumpEdit(tester);

      expect(find.text('07:00'), findsOneWidget);
      expect(
        tester
            .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
            .selected,
        {1},
      );
    });

    testWidgets('tapping 隔週 selects it', (tester) async {
      await pumpEdit(tester);

      await tester.tap(find.text('隔週'));
      await settle(tester);

      expect(
        tester
            .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
            .selected,
        {2},
      );
    });

    testWidgets(
      'removing the only notification time shows a validation message on save',
      (tester) async {
        await pumpEdit(tester);
        await tester.enterText(find.byType(TextField).first, '保育園');
        await tester.tap(find.text('持ち物を追加'));
        await settle(tester);
        await tester.enterText(find.byType(TextField).at(1), '連絡帳');

        await tester.tap(find.byIcon(Icons.remove_circle_outline));
        await settle(tester);
        await tester.tap(find.text('保存'));
        await tester.pump();

        expect(find.text('通知時刻を1つ以上設定してください'), findsOneWidget);
        expect(TodoSetRepository().getAll(), isEmpty);
      },
    );
  });
}
