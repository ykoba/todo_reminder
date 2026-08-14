import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/data/checklist_repository.dart';
import 'package:todo_reminder/data/todo_set_repository.dart';
import 'package:todo_reminder/screens/checklist_history_screen.dart';
import 'package:todo_reminder/utils/date_key.dart';

import '../support/fixtures.dart';
import '../support/hive_test_harness.dart';
import '../support/pump_helpers.dart';

void main() {
  final harness = HiveTestHarness();

  setUp(() => harness.setUp());
  tearDown(() => harness.tearDown());

  Future<void> pumpHistory(WidgetTester tester, String todoSetId) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: ChecklistHistoryScreen(todoSetId: todoSetId))));
    await settle(tester);
  }

  testWidgets('shows the set name in the title and the current month/weekday headers', (tester) async {
    final today = DateTime.now();
    await tester.runAsync(() => TodoSetRepository().save(buildTodoSet(id: 'set-1', name: '保育園')));

    await pumpHistory(tester, 'set-1');

    expect(find.text('保育園の完了履歴'), findsOneWidget);
    expect(find.text('${today.year}年${today.month}月'), findsOneWidget);
    expect(find.text('月'), findsOneWidget);
    expect(find.text('日'), findsOneWidget);
  });

  testWidgets('tapping a completed day shows its status and checked count', (tester) async {
    final today = DateTime.now();
    await tester.runAsync(() async {
      final set = buildTodoSet(id: 'set-1', name: '保育園');
      await TodoSetRepository().save(set);
      final checklist = ChecklistRepository().getOrCreate(set, todayKey());
      await ChecklistRepository().toggleItem(checklist, set.items.first.id);
      await ChecklistRepository().setCompleted(checklist, true);
    });

    await pumpHistory(tester, 'set-1');
    await tester.tap(find.text('${today.day}'));
    await settle(tester);

    expect(find.textContaining('完了（1件チェック）'), findsOneWidget);
  });

  testWidgets('the status toast is shown for 2 seconds', (tester) async {
    await tester.runAsync(() => TodoSetRepository().save(buildTodoSet(id: 'set-1', name: '保育園')));

    await pumpHistory(tester, 'set-1');
    await tester.tap(find.text('1'));
    await tester.pump();

    expect(tester.widget<SnackBar>(find.byType(SnackBar)).duration, const Duration(seconds: 2));
  });

  testWidgets(
    'tapping another day while the toast is showing replaces it immediately',
    (tester) async {
      final today = DateTime.now();
      await tester.runAsync(() async {
        final set = buildTodoSet(id: 'set-1', name: '保育園');
        await TodoSetRepository().save(set);
        final checklist = ChecklistRepository().getOrCreate(set, todayKey());
        await ChecklistRepository().toggleItem(checklist, set.items.first.id);
        await ChecklistRepository().setCompleted(checklist, true);
      });

      await pumpHistory(tester, 'set-1');
      await tester.tap(find.text('1'));
      await tester.pump();
      expect(find.textContaining('記録なし'), findsOneWidget);

      // Tap the other day well before the first toast's 2-second duration
      // would have elapsed.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('${today.day}'));
      // The old SnackBar's removal and the new one's entrance transition
      // both need more than a single pump to finish.
      await settle(tester);

      expect(find.textContaining('記録なし'), findsNothing);
      expect(find.textContaining('完了（1件チェック）'), findsOneWidget);
    },
    // Day 1 (no record) and today (seeded as completed) need to be two
    // distinct, both-tappable cells; on the 1st of the month they're the
    // same cell — and every *other* day is in the future — so there's no
    // way to pick two such days on that date. Skip rather than flake.
    skip: DateTime.now().day == 1,
  );

  testWidgets('tapping a day with no record shows "記録なし"', (tester) async {
    // Use the 1st of the month, which is never in the future relative to
    // "today" and is always tappable regardless of what day it is run on.
    await tester.runAsync(() => TodoSetRepository().save(buildTodoSet(id: 'set-1', name: '保育園')));

    await pumpHistory(tester, 'set-1');
    await tester.tap(find.text('1'));
    await settle(tester);

    expect(find.textContaining('記録なし'), findsOneWidget);
  });

  testWidgets('cannot navigate past the current month', (tester) async {
    await tester.runAsync(() => TodoSetRepository().save(buildTodoSet(id: 'set-1', name: '保育園')));

    await pumpHistory(tester, 'set-1');

    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull);
  });

  testWidgets('the previous-month button moves the header back a month', (tester) async {
    final today = DateTime.now();
    final previousMonth = DateTime(today.year, today.month - 1);
    await tester.runAsync(() => TodoSetRepository().save(buildTodoSet(id: 'set-1', name: '保育園')));

    await pumpHistory(tester, 'set-1');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
    await settle(tester);

    expect(find.text('${previousMonth.year}年${previousMonth.month}月'), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed,
      isNotNull,
    );
  });

  testWidgets('shows a legend explaining the day markers', (tester) async {
    await tester.runAsync(() => TodoSetRepository().save(buildTodoSet(id: 'set-1', name: '保育園')));

    await pumpHistory(tester, 'set-1');

    expect(find.text('完了'), findsOneWidget);
    expect(find.text('記録あり（未完了）'), findsOneWidget);
  });
}
