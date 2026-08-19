import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/data/checklist_repository.dart';
import 'package:todo_reminder/data/todo_set_repository.dart';
import 'package:todo_reminder/models/todo_set.dart';
import 'package:todo_reminder/screens/checklist_screen.dart';
import 'package:todo_reminder/screens/todo_set_edit_screen.dart';
import 'package:todo_reminder/utils/date_key.dart';

import '../support/fixtures.dart';
import '../support/hive_test_harness.dart';
import '../support/pump_helpers.dart';

// These tests cover how ChecklistScreen renders a given state (item labels,
// progress count, the completed banner/button). They deliberately don't tap
// a checkbox or the complete/undo button and then assert on the result: in
// this test environment, a real Hive write triggered from inside a widget
// callback doesn't reliably signal its own completion back to the awaiting
// code, and no combination of pump()/pumpAndSettle()/runAsync() found so
// far makes that reliable. ChecklistRepository.toggleItem/setCompleted
// themselves are covered thoroughly and reliably in
// data/checklist_repository_test.dart; here, the state they'd produce is
// seeded directly and the screen's rendering of it is what's under test.
void main() {
  final harness = HiveTestHarness();

  setUp(() => harness.setUp());
  tearDown(() => harness.tearDown());

  // Seeding via tester.runAsync(): a Hive write made in the plain test zone
  // before the first pumpWidget deadlocks pumpWidget once a screen
  // subscribes to that box's watch() stream (as ChecklistScreen does).
  //
  // This also pre-creates today's DailyChecklist so that
  // ChecklistScreen.initState()'s own getOrCreate() call (which runs
  // synchronously *during* the first pumpWidget, alongside this screen's own
  // stream subscriptions) finds an existing record and skips writing one —
  // a Hive write made from inside initState() during pumpWidget itself was
  // similarly unreliable to wait out.
  Future<TodoSet> seedTodoSet(
    WidgetTester tester, {
    List<String> itemLabels = const ['連絡帳', '水筒', 'タオル'],
  }) async {
    final set = buildTodoSet(
      id: 'set-1',
      name: '保育園',
      items: [
        for (var i = 0; i < itemLabels.length; i++)
          buildTodoItem(label: itemLabels[i], sortOrder: i),
      ],
    );
    await tester.runAsync(() async {
      await TodoSetRepository().save(set);
      ChecklistRepository().getOrCreate(set, todayKey());
    });
    return set;
  }

  Future<void> pumpChecklist(WidgetTester tester, String todoSetId) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: ChecklistScreen(todoSetId: todoSetId)),
      ),
    );
    await settle(tester);
  }

  testWidgets(
    'shows the set name, all item labels, and an initial 0/N progress',
    (tester) async {
      final set = await seedTodoSet(tester);

      await pumpChecklist(tester, set.id);

      expect(find.text('保育園'), findsOneWidget);
      expect(find.text('連絡帳'), findsOneWidget);
      expect(find.text('水筒'), findsOneWidget);
      expect(find.text('タオル'), findsOneWidget);
      expect(find.text('0/3 チェック済み'), findsOneWidget);
    },
  );

  testWidgets('shows a checked item and the matching progress count', (
    tester,
  ) async {
    final set = await seedTodoSet(tester);
    await tester.runAsync(() async {
      final checklist = ChecklistRepository().getOrCreate(set, todayKey());
      await ChecklistRepository().toggleItem(checklist, set.items.first.id);
    });

    await pumpChecklist(tester, set.id);

    expect(find.text('1/3 チェック済み'), findsOneWidget);
    final checkbox = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, '連絡帳'),
    );
    expect(checkbox.value, isTrue);
  });

  testWidgets(
    'shows the completed banner with an inline undo link when already completed',
    (tester) async {
      final set = await seedTodoSet(tester);
      await tester.runAsync(() async {
        final checklist = ChecklistRepository().getOrCreate(set, todayKey());
        await ChecklistRepository().setCompleted(checklist, true);
      });

      await pumpChecklist(tester, set.id);

      expect(find.text('本日は完了しました'), findsOneWidget);
      expect(find.text('取り消す'), findsOneWidget);
    },
  );

  testWidgets('shows no completed banner when not completed', (
    tester,
  ) async {
    final set = await seedTodoSet(tester);

    await pumpChecklist(tester, set.id);

    expect(find.text('本日は完了しました'), findsNothing);
    expect(find.text('取り消す'), findsNothing);
  });

  testWidgets(
    'shows a placeholder instead of a progress bar crash when there are no items',
    (tester) async {
      final set = await seedTodoSet(tester, itemLabels: const []);

      await pumpChecklist(tester, set.id);

      expect(find.text('持ち物がありません'), findsOneWidget);
      expect(find.text('0/0 チェック済み'), findsOneWidget);
    },
  );

  testWidgets('tapping the edit icon opens the edit screen for this set', (
    tester,
  ) async {
    final set = await seedTodoSet(tester);

    await pumpChecklist(tester, set.id);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await settle(tester);

    expect(find.byType(TodoSetEditScreen), findsOneWidget);
    expect(find.text('セットを編集'), findsOneWidget);
  });

  testWidgets('shows a memo field pre-filled with the day\'s saved memo', (
    tester,
  ) async {
    final set = await seedTodoSet(tester);
    await tester.runAsync(() async {
      final checklist = ChecklistRepository().getOrCreate(set, todayKey());
      await ChecklistRepository().setMemo(checklist, '発熱のため早退');
    });

    await pumpChecklist(tester, set.id);

    expect(find.widgetWithText(TextFormField, '発熱のため早退'), findsOneWidget);
    expect(find.text('メモ'), findsOneWidget);
  });

  testWidgets(
    'shows an unchecked "すべてチェック" control at the top of the list',
    (tester) async {
      final set = await seedTodoSet(tester);

      await pumpChecklist(tester, set.id);

      final selectAll = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'すべてチェック'),
      );
      expect(selectAll.value, isFalse);
    },
  );

  testWidgets(
    '"すべてチェック" is checked once every item is already checked',
    (tester) async {
      final set = await seedTodoSet(tester, itemLabels: const ['連絡帳']);
      await tester.runAsync(() async {
        final checklist = ChecklistRepository().getOrCreate(set, todayKey());
        await ChecklistRepository().toggleItem(checklist, set.items.first.id);
      });

      await pumpChecklist(tester, set.id);

      final selectAll = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'すべてチェック'),
      );
      expect(selectAll.value, isTrue);
    },
  );

  testWidgets(
    'does not show the "すべてチェック" control when there are no items',
    (tester) async {
      final set = await seedTodoSet(tester, itemLabels: const []);

      await pumpChecklist(tester, set.id);

      expect(find.text('すべてチェック'), findsNothing);
    },
  );
}
