import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/data/checklist_repository.dart';
import 'package:todo_reminder/data/todo_set_repository.dart';
import 'package:todo_reminder/screens/checklist_screen.dart';
import 'package:todo_reminder/utils/date_key.dart';

import '../support/fixtures.dart';
import '../support/hive_test_harness.dart';
import '../support/pump_helpers.dart';

// Regression test for the underlying TodoSet disappearing while
// ChecklistScreen is on screen (e.g. deleted via TodoSetEditScreen's delete
// icon, reached from this screen's own edit icon, which pops back to here
// once done). Without ChecklistScreen's ref.listen-driven auto-pop, the
// `todoSet == null` branch shows a spinner forever instead of closing.
void main() {
  final harness = HiveTestHarness();

  setUp(() => harness.setUp());
  tearDown(() => harness.tearDown());

  testWidgets(
    'pops itself if its TodoSet is deleted while it is showing',
    (tester) async {
      final set = buildTodoSet(id: 'set-1', name: '保育園');
      await tester.runAsync(() async {
        await TodoSetRepository().save(set);
        ChecklistRepository().getOrCreate(set, todayKey());
      });

      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: const Scaffold(body: Text('list screen stand-in')),
          ),
        ),
      );
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => const ChecklistScreen(todoSetId: 'set-1'),
        ),
      );
      await settle(tester);
      expect(find.byType(ChecklistScreen), findsOneWidget);

      await tester.runAsync(() => TodoSetRepository().delete('set-1'));
      await settle(tester);

      expect(find.byType(ChecklistScreen), findsNothing);
      expect(find.text('list screen stand-in'), findsOneWidget);
    },
  );
}
