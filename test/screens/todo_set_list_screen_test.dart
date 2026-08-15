import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/data/checklist_repository.dart';
import 'package:todo_reminder/data/todo_set_repository.dart';
import 'package:todo_reminder/screens/checklist_screen.dart';
import 'package:todo_reminder/screens/privacy_policy_screen.dart';
import 'package:todo_reminder/screens/todo_set_edit_screen.dart';
import 'package:todo_reminder/screens/todo_set_list_screen.dart';
import 'package:todo_reminder/notifications/notification_service.dart';
import 'package:todo_reminder/utils/date_key.dart';
import 'package:todo_reminder/utils/schedule_format.dart';
import 'package:todo_reminder/utils/todo_set_icons.dart';

import '../support/fixtures.dart';
import '../support/hive_test_harness.dart';
import '../support/notification_channel_mocks.dart';
import '../support/pump_helpers.dart';

void main() {
  final harness = HiveTestHarness();

  setUp(() async {
    await harness.setUp();
    final log = mockNotificationChannels();
    // scheduleForTodoSet() (triggered by saving) needs tz.local, which is
    // only set up by NotificationService.init() — normally called once from
    // main() at app startup, so tests must call it themselves.
    await NotificationService.instance.init();
    log.clear();
  });

  tearDown(() async {
    teardownMockNotificationChannels();
    await harness.tearDown();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TodoSetListScreen())),
    );
    await settle(tester);
  }

  testWidgets('shows empty-state guidance when there are no TodoSets', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('右下の + からTodoセットを作成してください'), findsOneWidget);
  });

  testWidgets('does not show a date header above the list', (tester) async {
    await tester.runAsync(
      () => TodoSetRepository().save(buildTodoSet(id: 'a', name: '保育園')),
    );

    await pumpScreen(tester);

    expect(find.text(formatJapaneseDate(DateTime.now())), findsNothing);
  });

  testWidgets(
    'lists a TodoSet with its name and schedule summary, without an item count',
    (tester) async {
      // Seeding via tester.runAsync(): a Hive write made in the plain test zone
      // before the first pumpWidget deadlocks pumpWidget once a screen
      // subscribes to that box's watch() stream (as TodoSetListScreen does).
      await tester.runAsync(
        () => TodoSetRepository().save(
          buildTodoSet(
            id: 'a',
            name: '保育園',
            items: [buildTodoItem(), buildTodoItem()],
            schedule: buildSchedule(
              hour: 7,
              minute: 0,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
            ),
          ),
        ),
      );

      await pumpScreen(tester);

      expect(find.text('保育園'), findsOneWidget);
      expect(find.text('毎日 07:00'), findsOneWidget);
      expect(find.textContaining('件'), findsNothing);
    },
  );

  testWidgets('shows the TodoSet\'s chosen icon', (tester) async {
    await tester.runAsync(
      () => TodoSetRepository().save(
        buildTodoSet(id: 'a', name: '保育園', icon: 'school'),
      ),
    );

    await pumpScreen(tester);

    expect(
      find.ancestor(
        of: find.byIcon(todoSetIcons['school']!),
        matching: find.byType(CircleAvatar),
      ),
      findsOneWidget,
    );
  });

  testWidgets('does not show a completion checkmark on the row', (
    tester,
  ) async {
    await tester.runAsync(
      () => TodoSetRepository().save(buildTodoSet(id: 'a', name: '保育園')),
    );

    await pumpScreen(tester);

    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.circle_outlined), findsNothing);
  });

  testWidgets('does not show an enabled/disabled switch on the row', (
    tester,
  ) async {
    // Whether a set is enabled is set from TodoSetEditScreen instead — see
    // todo_set_edit_screen_test.dart's "enabled switch" coverage.
    await tester.runAsync(
      () => TodoSetRepository().save(buildTodoSet(id: 'a', name: '保育園')),
    );

    await pumpScreen(tester);

    expect(find.byType(Switch), findsNothing);
  });

  group('reorder mode', () {
    // Simulating the actual drag gesture isn't covered here: it would fight
    // the same real-Hive-write-timing issues documented throughout this
    // file. The repository-level contract that onReorderItem relies on
    // (List.removeAt/insert + TodoSetRepository.reorder) is covered
    // directly and reliably in data/todo_set_repository_test.dart.
    testWidgets(
      'hides drag handles until reorder mode is entered via the sort button',
      (tester) async {
        await tester.runAsync(() async {
          await TodoSetRepository().save(
            buildTodoSet(id: 'a', name: 'A', sortOrder: 0),
          );
          await TodoSetRepository().save(
            buildTodoSet(id: 'b', name: 'B', sortOrder: 1),
          );
        });

        await pumpScreen(tester);
        expect(find.byIcon(Icons.drag_handle), findsNothing);

        await tester.tap(find.byIcon(Icons.sort));
        await settle(tester);

        expect(find.text('並び替え'), findsOneWidget);
        expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
      },
    );

    testWidgets('tapping 完了 in reorder mode returns to the normal list', (
      tester,
    ) async {
      await tester.runAsync(
        () => TodoSetRepository().save(buildTodoSet(id: 'a', name: 'A')),
      );

      await pumpScreen(tester);
      await tester.tap(find.byIcon(Icons.sort));
      await settle(tester);
      expect(find.byIcon(Icons.drag_handle), findsOneWidget);

      await tester.tap(find.text('完了'));
      await settle(tester);

      expect(find.byIcon(Icons.drag_handle), findsNothing);
      expect(find.text('持ち物リマインダー'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNWidgets(3));
    });

    testWidgets('hides the FAB and edit button while reordering', (
      tester,
    ) async {
      await tester.runAsync(
        () => TodoSetRepository().save(buildTodoSet(id: 'a', name: 'A')),
      );

      await pumpScreen(tester);
      await tester.tap(find.byIcon(Icons.sort));
      await settle(tester);

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });
  });

  group('edit mode', () {
    testWidgets(
      'hides the edit button on each row until edit mode is entered via the edit FAB',
      (tester) async {
        await tester.runAsync(
          () => TodoSetRepository().save(buildTodoSet(id: 'a', name: '保育園')),
        );

        await pumpScreen(tester);
        expect(
          find.byIcon(Icons.edit_outlined),
          findsOneWidget,
        ); // edit FAB only

        await tester.tap(find.byIcon(Icons.edit_outlined));
        await settle(tester);

        expect(find.text('編集'), findsOneWidget);
        expect(
          find.byIcon(Icons.edit_outlined),
          findsOneWidget,
        ); // per-row button
      },
    );

    testWidgets('tapping 完了 in edit mode returns to the normal list', (
      tester,
    ) async {
      await tester.runAsync(
        () => TodoSetRepository().save(buildTodoSet(id: 'a', name: '保育園')),
      );

      await pumpScreen(tester);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await settle(tester);

      await tester.tap(find.text('完了'));
      await settle(tester);

      expect(find.text('持ち物リマインダー'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNWidgets(3));
    });

    testWidgets('hides the FAB and sort button while editing', (tester) async {
      await tester.runAsync(
        () => TodoSetRepository().save(buildTodoSet(id: 'a', name: '保育園')),
      );

      await pumpScreen(tester);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await settle(tester);

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byIcon(Icons.sort), findsNothing);
    });

    testWidgets(
      'tapping the row\'s edit button opens the edit screen pre-filled with the set name',
      (tester) async {
        await tester.runAsync(
          () => TodoSetRepository().save(buildTodoSet(id: 'a', name: '保育園')),
        );

        await pumpScreen(tester);
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await settle(tester);
        await tester.tap(find.byIcon(Icons.edit_outlined).last);
        await settle(tester);

        expect(find.text('セットを編集'), findsOneWidget);
        expect(find.text('保育園'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the row itself while editing also opens the edit screen',
      (tester) async {
        await tester.runAsync(
          () => TodoSetRepository().save(buildTodoSet(id: 'a', name: '保育園')),
        );

        await pumpScreen(tester);
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await settle(tester);
        await tester.tap(find.text('保育園'));
        await settle(tester);

        expect(find.text('セットを編集'), findsOneWidget);
      },
    );
  });

  group('settings menu', () {
    // Theme selection and the privacy policy link are app-level settings,
    // so they're grouped into a single overflow menu rather than each
    // getting their own AppBar icon.
    testWidgets(
      'defaults to following the system setting and offers all three theme options plus the privacy policy link',
      (tester) async {
        await pumpScreen(tester);

        expect(find.byIcon(Icons.brightness_auto_outlined), findsOneWidget);

        await tester.tap(find.byIcon(Icons.brightness_auto_outlined));
        await settle(tester);

        expect(find.text('端末の設定に従う'), findsOneWidget);
        expect(find.text('ライト'), findsOneWidget);
        expect(find.text('ダーク'), findsOneWidget);
        expect(find.text('プライバシーポリシー'), findsOneWidget);
      },
    );

    testWidgets('tapping プライバシーポリシー opens the privacy policy screen', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.byIcon(Icons.brightness_auto_outlined));
      await settle(tester);
      await tester.tap(find.text('プライバシーポリシー'));
      await settle(tester);

      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    });
  });

  testWidgets('the reorder and edit FABs are smaller than the main add FAB', (
    tester,
  ) async {
    await pumpScreen(tester);

    final addSize = tester.getSize(
      find.widgetWithIcon(FloatingActionButton, Icons.add),
    );
    final sortSize = tester.getSize(
      find.widgetWithIcon(FloatingActionButton, Icons.sort),
    );
    final editSize = tester.getSize(
      find.widgetWithIcon(FloatingActionButton, Icons.edit_outlined),
    );

    expect(sortSize.width, lessThan(addSize.width));
    expect(editSize.width, lessThan(addSize.width));
  });

  testWidgets('tapping the add FAB opens the create screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithIcon(FloatingActionButton, Icons.add));
    await settle(tester);

    expect(find.byType(TodoSetEditScreen), findsOneWidget);
    expect(find.text('セットを作成'), findsOneWidget);
  });

  testWidgets('tapping a row in the normal list opens the checklist screen', (
    tester,
  ) async {
    // Pre-creating today's DailyChecklist here too: ChecklistScreen (the
    // destination) writes one in its own initState() if none exists yet,
    // and a Hive write made during another widget's build phase was
    // similarly unreliable to wait out — see checklist_screen_test.dart.
    await tester.runAsync(() async {
      final set = buildTodoSet(id: 'a', name: '保育園');
      await TodoSetRepository().save(set);
      ChecklistRepository().getOrCreate(set, todayKey());
    });

    await pumpScreen(tester);
    await tester.tap(find.text('保育園'));
    await settle(tester);

    expect(find.byType(ChecklistScreen), findsOneWidget);
  });
}
