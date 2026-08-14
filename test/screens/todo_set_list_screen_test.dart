import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/data/checklist_repository.dart';
import 'package:todo_reminder/data/todo_set_repository.dart';
import 'package:todo_reminder/screens/checklist_screen.dart';
import 'package:todo_reminder/screens/todo_set_edit_screen.dart';
import 'package:todo_reminder/screens/todo_set_list_screen.dart';
import 'package:todo_reminder/notifications/notification_service.dart';
import 'package:todo_reminder/utils/date_key.dart';
import 'package:todo_reminder/utils/schedule_format.dart';

import '../support/fixtures.dart';
import '../support/hive_test_harness.dart';
import '../support/notification_channel_mocks.dart';
import '../support/pump_helpers.dart';

void main() {
  final harness = HiveTestHarness();

  setUp(() async {
    await harness.setUp();
    final log = mockNotificationChannels();
    // scheduleForTodoSet() (triggered by the enable/disable switch) needs
    // tz.local, which is only set up by NotificationService.init() —
    // normally called once from main() at app startup, so tests must call
    // it themselves.
    await NotificationService.instance.init();
    log.clear();
  });

  tearDown(() async {
    teardownMockNotificationChannels();
    await harness.tearDown();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: TodoSetListScreen())));
    await settle(tester);
  }

  testWidgets('shows empty-state guidance when there are no TodoSets', (tester) async {
    await pumpScreen(tester);

    expect(find.text('右下の + からTodoセットを作成してください'), findsOneWidget);
  });

  testWidgets('shows today\'s date above the list', (tester) async {
    await pumpScreen(tester);

    expect(find.text(formatJapaneseDate(DateTime.now())), findsOneWidget);
  });

  testWidgets('lists a TodoSet with its name and a schedule/item-count summary', (tester) async {
    // Seeding via tester.runAsync(): a Hive write made in the plain test zone
    // before the first pumpWidget deadlocks pumpWidget once a screen
    // subscribes to that box's watch() stream (as TodoSetListScreen does).
    await tester.runAsync(() => TodoSetRepository().save(buildTodoSet(
          id: 'a',
          name: '保育園',
          items: [buildTodoItem(), buildTodoItem()],
          schedule: buildSchedule(hour: 7, minute: 0, repeatDays: [1, 2, 3, 4, 5, 6, 7]),
        )));

    await pumpScreen(tester);

    expect(find.text('保育園'), findsOneWidget);
    expect(find.text('毎日 07:00 ・ 2件'), findsOneWidget);
  });

  // Simulating the actual drag gesture isn't covered here: it would fight
  // the same real-Hive-write-timing issues documented throughout this file.
  // The repository-level contract that onReorderItem relies on
  // (List.removeAt/insert + TodoSetRepository.reorder) is covered directly
  // and reliably in data/todo_set_repository_test.dart.
  testWidgets('shows a drag handle for reordering on each row', (tester) async {
    await tester.runAsync(() async {
      await TodoSetRepository().save(buildTodoSet(id: 'a', name: 'A', sortOrder: 0));
      await TodoSetRepository().save(buildTodoSet(id: 'b', name: 'B', sortOrder: 1));
    });

    await pumpScreen(tester);

    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
  });

  testWidgets('shows a filled check icon when today\'s checklist is already completed', (tester) async {
    await tester.runAsync(() async {
      final set = buildTodoSet(id: 'a');
      await TodoSetRepository().save(set);
      final checklist = ChecklistRepository().getOrCreate(set, todayKey());
      await ChecklistRepository().setCompleted(checklist, true);
    });

    await pumpScreen(tester);

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.circle_outlined), findsNothing);
  });

  testWidgets('shows an outlined circle icon when today is not completed yet', (tester) async {
    await tester.runAsync(() => TodoSetRepository().save(buildTodoSet(id: 'a')));

    await pumpScreen(tester);

    expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  // Toggling the switch and asserting on the result isn't covered at this
  // level: in this test environment, a real Hive write triggered from
  // inside a widget callback doesn't reliably signal its own completion
  // back to the awaiting code, and no pump()/pumpAndSettle()/runAsync()
  // combination found so far makes that reliable. The switch's onChanged
  // handler calls TodoSetRepository.save(), which is covered thoroughly and
  // reliably in data/todo_set_repository_test.dart; here, only that the
  // switch reflects the current isEnabled is checked (read-only).
  testWidgets('switch reflects the set\'s isEnabled value', (tester) async {
    await tester.runAsync(() => TodoSetRepository().save(buildTodoSet(id: 'a', isEnabled: false)));

    await pumpScreen(tester);

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('theme menu defaults to following the system setting and offers all three options', (tester) async {
    await pumpScreen(tester);

    expect(find.byIcon(Icons.brightness_auto_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.brightness_auto_outlined));
    await settle(tester);

    expect(find.text('端末の設定に従う'), findsOneWidget);
    expect(find.text('ライト'), findsOneWidget);
    expect(find.text('ダーク'), findsOneWidget);
  });

  testWidgets('tapping the FAB opens the create screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);

    expect(find.byType(TodoSetEditScreen), findsOneWidget);
    expect(find.text('セットを作成'), findsOneWidget);
  });

  testWidgets('tapping the edit icon opens the edit screen pre-filled with the set name', (tester) async {
    await tester.runAsync(() => TodoSetRepository().save(buildTodoSet(id: 'a', name: '保育園')));

    await pumpScreen(tester);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await settle(tester);

    expect(find.text('セットを編集'), findsOneWidget);
    expect(find.text('保育園'), findsOneWidget);
  });

  testWidgets('tapping a row opens the checklist screen for that set', (tester) async {
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
