import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/data/checklist_repository.dart';

import '../support/fixtures.dart';
import '../support/hive_test_harness.dart';

void main() {
  final harness = HiveTestHarness();
  late ChecklistRepository repository;

  setUp(() async {
    await harness.setUp();
    repository = ChecklistRepository();
  });

  tearDown(() => harness.tearDown());

  group('getOrCreate', () {
    test('creates an empty checklist on first access', () {
      final todoSet = buildTodoSet(id: 'set-1');

      final checklist = repository.getOrCreate(todoSet, '2026-01-01');

      expect(checklist.todoSetId, 'set-1');
      expect(checklist.dateKey, '2026-01-01');
      expect(checklist.checkedItemIds, isEmpty);
      expect(checklist.isCompleted, isFalse);
    });

    test(
      'persists the created checklist so a plain get() finds it afterward',
      () {
        final todoSet = buildTodoSet(id: 'set-1');

        repository.getOrCreate(todoSet, '2026-01-01');

        expect(repository.get('set-1', '2026-01-01'), isNotNull);
      },
    );

    test(
      'returns the same record on repeated calls instead of resetting progress',
      () {
        final todoSet = buildTodoSet(
          id: 'set-1',
          items: [buildTodoItem(id: 'item-1')],
        );

        final first = repository.getOrCreate(todoSet, '2026-01-01');
        repository.toggleItem(first, 'item-1');

        final second = repository.getOrCreate(todoSet, '2026-01-01');

        expect(second.isChecked('item-1'), isTrue);
      },
    );

    test(
      'keeps checklists for the same todoSet on different dates independent',
      () {
        final todoSet = buildTodoSet(
          id: 'set-1',
          items: [buildTodoItem(id: 'item-1')],
        );

        final day1 = repository.getOrCreate(todoSet, '2026-01-01');
        repository.toggleItem(day1, 'item-1');
        final day2 = repository.getOrCreate(todoSet, '2026-01-02');

        expect(day2.isChecked('item-1'), isFalse);
      },
    );

    test(
      'keeps checklists for different todoSets on the same date independent',
      () {
        final setA = buildTodoSet(
          id: 'set-a',
          items: [buildTodoItem(id: 'item-1')],
        );
        final setB = buildTodoSet(
          id: 'set-b',
          items: [buildTodoItem(id: 'item-1')],
        );

        final checklistA = repository.getOrCreate(setA, '2026-01-01');
        repository.toggleItem(checklistA, 'item-1');
        final checklistB = repository.getOrCreate(setB, '2026-01-01');

        expect(checklistB.isChecked('item-1'), isFalse);
      },
    );
  });

  test('get returns null when no checklist has been created for that key', () {
    expect(repository.get('set-1', '2026-01-01'), isNull);
  });

  group('getAllForTodoSet', () {
    test('returns an empty map when nothing has been recorded', () {
      expect(repository.getAllForTodoSet('set-1'), isEmpty);
    });

    test('returns every recorded date for that todoSet, keyed by dateKey', () {
      final todoSet = buildTodoSet(id: 'set-1');
      repository.getOrCreate(todoSet, '2026-01-01');
      repository.getOrCreate(todoSet, '2026-01-02');

      final history = repository.getAllForTodoSet('set-1');

      expect(history.keys.toSet(), {'2026-01-01', '2026-01-02'});
      expect(history['2026-01-01']!.dateKey, '2026-01-01');
    });

    test('excludes records belonging to a different todoSet', () {
      final setA = buildTodoSet(id: 'set-a');
      final setB = buildTodoSet(id: 'set-b');
      repository.getOrCreate(setA, '2026-01-01');
      repository.getOrCreate(setB, '2026-01-01');

      final history = repository.getAllForTodoSet('set-a');

      expect(history.keys, ['2026-01-01']);
      expect(history['2026-01-01']!.todoSetId, 'set-a');
    });
  });

  // toggleItem/setCompleted call HiveObject.save(), which requires the
  // object to already be attached to a box — so these tests build their
  // fixture through getOrCreate() rather than constructing a standalone
  // DailyChecklist directly.
  group('toggleItem', () {
    test('checks an unchecked item', () async {
      final todoSet = buildTodoSet(id: 'set-1');
      final checklist = repository.getOrCreate(todoSet, '2026-01-01');

      await repository.toggleItem(checklist, 'item-1');

      expect(checklist.isChecked('item-1'), isTrue);
    });

    test('unchecks an already-checked item', () async {
      final todoSet = buildTodoSet(id: 'set-1');
      final checklist = repository.getOrCreate(todoSet, '2026-01-01');
      await repository.toggleItem(checklist, 'item-1');

      await repository.toggleItem(checklist, 'item-1');

      expect(checklist.isChecked('item-1'), isFalse);
    });

    test('toggling twice returns to the original state', () async {
      final todoSet = buildTodoSet(id: 'set-1');
      final checklist = repository.getOrCreate(todoSet, '2026-01-01');

      await repository.toggleItem(checklist, 'item-1');
      await repository.toggleItem(checklist, 'item-1');

      expect(checklist.isChecked('item-1'), isFalse);
    });

    test('toggling one item does not affect other checked items', () async {
      final todoSet = buildTodoSet(id: 'set-1');
      final checklist = repository.getOrCreate(todoSet, '2026-01-01');
      await repository.toggleItem(checklist, 'item-1');

      await repository.toggleItem(checklist, 'item-2');

      expect(checklist.isChecked('item-1'), isTrue);
      expect(checklist.isChecked('item-2'), isTrue);
    });

    test('persists the change so a fresh read reflects it', () async {
      final todoSet = buildTodoSet(id: 'set-1');
      final checklist = repository.getOrCreate(todoSet, '2026-01-01');

      await repository.toggleItem(checklist, 'item-1');

      expect(
        repository.get('set-1', '2026-01-01')!.isChecked('item-1'),
        isTrue,
      );
    });
  });

  group('setCompleted', () {
    test('true sets completedAt to a non-null timestamp', () async {
      final todoSet = buildTodoSet(id: 'set-1');
      final checklist = repository.getOrCreate(todoSet, '2026-01-01');

      await repository.setCompleted(checklist, true);

      expect(checklist.isCompleted, isTrue);
      expect(checklist.completedAt, isNotNull);
    });

    test('false clears completedAt back to null', () async {
      final todoSet = buildTodoSet(id: 'set-1');
      final checklist = repository.getOrCreate(todoSet, '2026-01-01');
      await repository.setCompleted(checklist, true);

      await repository.setCompleted(checklist, false);

      expect(checklist.isCompleted, isFalse);
      expect(checklist.completedAt, isNull);
    });
  });

  group('setAllChecked', () {
    test('checked: true marks every given id as checked', () async {
      final todoSet = buildTodoSet(id: 'set-1');
      final checklist = repository.getOrCreate(todoSet, '2026-01-01');

      await repository.setAllChecked(checklist, ['item-1', 'item-2'], true);

      expect(checklist.isChecked('item-1'), isTrue);
      expect(checklist.isChecked('item-2'), isTrue);
    });

    test(
      'checked: false clears every checked item, ignoring the id list',
      () async {
        final todoSet = buildTodoSet(id: 'set-1');
        final checklist = repository.getOrCreate(todoSet, '2026-01-01');
        await repository.toggleItem(checklist, 'item-1');
        await repository.toggleItem(checklist, 'item-2');

        await repository.setAllChecked(checklist, [], false);

        expect(checklist.checkedItemIds, isEmpty);
      },
    );

    test('persists the change so a fresh read reflects it', () async {
      final todoSet = buildTodoSet(id: 'set-1');
      final checklist = repository.getOrCreate(todoSet, '2026-01-01');

      await repository.setAllChecked(checklist, ['item-1'], true);

      expect(
        repository.get('set-1', '2026-01-01')!.isChecked('item-1'),
        isTrue,
      );
    });
  });

  group('setMemo', () {
    test('persists the memo text', () async {
      final todoSet = buildTodoSet(id: 'set-1');
      final checklist = repository.getOrCreate(todoSet, '2026-01-01');

      await repository.setMemo(checklist, '発熱のため早退');

      expect(checklist.memo, '発熱のため早退');
      expect(repository.get('set-1', '2026-01-01')!.memo, '発熱のため早退');
    });

    test('an empty memo is the default for a newly created checklist', () {
      final todoSet = buildTodoSet(id: 'set-1');

      final checklist = repository.getOrCreate(todoSet, '2026-01-01');

      expect(checklist.memo, '');
    });
  });
}
