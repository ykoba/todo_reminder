import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/data/todo_set_repository.dart';

import '../support/fixtures.dart';
import '../support/hive_test_harness.dart';

void main() {
  final harness = HiveTestHarness();
  late TodoSetRepository repository;

  setUp(() async {
    await harness.setUp();
    repository = TodoSetRepository();
  });

  tearDown(() => harness.tearDown());

  group('getAll', () {
    test('returns an empty list when nothing has been saved', () {
      expect(repository.getAll(), isEmpty);
    });

    test('returns saved sets ordered by sortOrder ascending, regardless of save order', () async {
      final last = buildTodoSet(id: 'last', sortOrder: 2);
      final first = buildTodoSet(id: 'first', sortOrder: 0);
      final middle = buildTodoSet(id: 'middle', sortOrder: 1);

      await repository.save(last);
      await repository.save(first);
      await repository.save(middle);

      expect(repository.getAll().map((s) => s.id).toList(), [
        'first',
        'middle',
        'last',
      ]);
    });
  });

  group('getById', () {
    test('returns null when no set matches the id', () {
      expect(repository.getById('missing'), isNull);
    });

    test('returns the matching set among several saved ones', () async {
      await repository.save(buildTodoSet(id: 'a'));
      await repository.save(buildTodoSet(id: 'b', name: 'Bセット'));

      final result = repository.getById('b');

      expect(result?.id, 'b');
      expect(result?.name, 'Bセット');
    });
  });

  group('save', () {
    test('overwrites an existing set with the same id', () async {
      await repository.save(buildTodoSet(id: 'a', name: '旧名'));
      await repository.save(buildTodoSet(id: 'a', name: '新名'));

      final sets = repository.getAll();

      expect(sets.length, 1);
      expect(sets.single.name, '新名');
    });

    test(
      'persists the chosen icon and reflects a later change to it',
      () async {
        await repository.save(buildTodoSet(id: 'a', icon: 'school'));
        expect(repository.getById('a')?.icon, 'school');

        await repository.save(buildTodoSet(id: 'a', icon: 'pets'));
        expect(repository.getById('a')?.icon, 'pets');
      },
    );

    test('persists a re-enabled isEnabled flag', () async {
      await repository.save(buildTodoSet(id: 'a', isEnabled: false));
      expect(repository.getById('a')?.isEnabled, isFalse);

      await repository.save(buildTodoSet(id: 'a', isEnabled: true));
      expect(repository.getById('a')?.isEnabled, isTrue);
    });
  });

  group('delete', () {
    test('removes the set with the given id', () async {
      await repository.save(buildTodoSet(id: 'a'));

      await repository.delete('a');

      expect(repository.getById('a'), isNull);
      expect(repository.getAll(), isEmpty);
    });

    test('deleting an id that does not exist does not throw', () async {
      await expectLater(repository.delete('missing'), completes);
    });
  });

  group('reorder', () {
    test(
      'rewrites sortOrder to match each set\'s position in the given list',
      () async {
        final a = buildTodoSet(id: 'a', sortOrder: 0);
        final b = buildTodoSet(id: 'b', sortOrder: 1);
        final c = buildTodoSet(id: 'c', sortOrder: 2);
        await repository.save(a);
        await repository.save(b);
        await repository.save(c);

        // Move 'c' to the front: [c, a, b].
        await repository.reorder([c, a, b]);

        expect(repository.getAll().map((s) => s.id).toList(), ['c', 'a', 'b']);
        expect(c.sortOrder, 0);
        expect(a.sortOrder, 1);
        expect(b.sortOrder, 2);
      },
    );

    test('persists the new order for a fresh read', () async {
      final a = buildTodoSet(id: 'a', sortOrder: 0);
      final b = buildTodoSet(id: 'b', sortOrder: 1);
      await repository.save(a);
      await repository.save(b);

      await repository.reorder([b, a]);

      expect(repository.getById('b')?.sortOrder, 0);
      expect(repository.getById('a')?.sortOrder, 1);
    });
  });

  group('replaceAll', () {
    test(
      'discards existing sets not present in the replacement list',
      () async {
        await repository.save(buildTodoSet(id: 'old'));

        await repository.replaceAll([buildTodoSet(id: 'new')]);

        expect(repository.getAll().map((set) => set.id), ['new']);
      },
    );

    test('persists every set in the replacement list', () async {
      await repository.replaceAll([
        buildTodoSet(id: 'a', name: 'A'),
        buildTodoSet(id: 'b', name: 'B'),
      ]);

      expect(repository.getAll().map((set) => set.id), ['a', 'b']);
    });

    test('an empty list clears all sets', () async {
      await repository.save(buildTodoSet(id: 'a'));

      await repository.replaceAll([]);

      expect(repository.getAll(), isEmpty);
    });
  });

  test('listenable notifies listeners when the box changes', () async {
    var notified = false;
    repository.listenable().addListener(() => notified = true);

    await repository.save(buildTodoSet(id: 'a'));
    await pumpEventQueue();

    expect(notified, isTrue);
  });
}
