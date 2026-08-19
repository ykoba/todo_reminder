import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/models/daily_checklist.dart';
import 'package:todo_reminder/providers/checklist_providers.dart';
import 'package:todo_reminder/providers/repository_providers.dart';

import '../support/fixtures.dart';
import '../support/hive_test_harness.dart';

void main() {
  final harness = HiveTestHarness();
  late ProviderContainer container;

  setUp(() async {
    await harness.setUp();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  tearDown(() => harness.tearDown());

  // Hive's box.watch() event, and Riverpod's re-emission from it, take a
  // few real event-loop turns (not just microtasks) to reach a listener
  // registered via container.listen — pumpEventQueue()'s zero-duration
  // timers aren't reliably enough of them, so poll with a real delay.
  Future<void> waitUntil(bool Function() ready) async {
    for (var i = 0; i < 300 && !ready(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  group('ChecklistKey', () {
    test('two keys with the same fields are equal and hash the same', () {
      const a = ChecklistKey(todoSetId: 'set-1', dateKey: '2026-01-01');
      const b = ChecklistKey(todoSetId: 'set-1', dateKey: '2026-01-01');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('keys with different todoSetId are not equal', () {
      const a = ChecklistKey(todoSetId: 'set-1', dateKey: '2026-01-01');
      const b = ChecklistKey(todoSetId: 'set-2', dateKey: '2026-01-01');

      expect(a == b, isFalse);
    });

    test('keys with different dateKey are not equal', () {
      const a = ChecklistKey(todoSetId: 'set-1', dateKey: '2026-01-01');
      const b = ChecklistKey(todoSetId: 'set-1', dateKey: '2026-01-02');

      expect(a == b, isFalse);
    });
  });

  group('dailyChecklistProvider', () {
    test('is null when no checklist has been created for that key', () async {
      const key = ChecklistKey(todoSetId: 'set-1', dateKey: '2026-01-01');

      final value = await container.read(dailyChecklistProvider(key).future);

      expect(value, isNull);
    });

    test('returns the checklist once created via the repository', () async {
      final todoSet = buildTodoSet(id: 'set-1');
      container
          .read(checklistRepositoryProvider)
          .getOrCreate(todoSet, '2026-01-01');

      const key = ChecklistKey(todoSetId: 'set-1', dateKey: '2026-01-01');
      final value = await container.read(dailyChecklistProvider(key).future);

      expect(value, isNotNull);
      expect(value!.todoSetId, 'set-1');
      expect(value.dateKey, '2026-01-01');
    });

    test('emits an update after an item is toggled', () async {
      final todoSet = buildTodoSet(id: 'set-1');
      final repo = container.read(checklistRepositoryProvider);
      final checklist = repo.getOrCreate(todoSet, '2026-01-01');

      // The listener must be registered before this provider is ever read
      // any other way (e.g. via `.future`): `_watchChecklist` is a
      // single-subscription Stream, and a prior `.future` read detaches
      // its one listener as soon as it resolves, permanently exhausting
      // the stream — no listener registered afterwards ever receives a
      // later update, no matter how long it waits.
      const key = ChecklistKey(todoSetId: 'set-1', dateKey: '2026-01-01');
      final events = <DailyChecklist?>[];
      final sub = container.listen(
        dailyChecklistProvider(key),
        (prev, next) => next.whenData(events.add),
      );
      addTearDown(sub.close);

      // The listener's own initial build (the current, pre-toggle value)
      // arrives asynchronously too; let it land and clear it so it isn't
      // mistaken for the update under test.
      await waitUntil(() => events.isNotEmpty);
      events.clear();

      await repo.toggleItem(checklist, 'item-1');
      await waitUntil(() => events.isNotEmpty);

      expect(events, isNotEmpty);
      expect(events.last?.isChecked('item-1'), isTrue);
    });

    test('a different (todoSetId, dateKey) key stays independent', () async {
      final todoSet = buildTodoSet(id: 'set-1');
      container
          .read(checklistRepositoryProvider)
          .getOrCreate(todoSet, '2026-01-01');

      const otherKey = ChecklistKey(todoSetId: 'set-1', dateKey: '2026-01-02');
      final value = await container.read(
        dailyChecklistProvider(otherKey).future,
      );

      expect(value, isNull);
    });
  });
}
