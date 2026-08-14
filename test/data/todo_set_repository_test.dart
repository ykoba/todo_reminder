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

    test('returns saved sets ordered by createdAt ascending, regardless of save order', () async {
      final newest = buildTodoSet(id: 'newest', createdAt: DateTime(2026, 3, 1));
      final oldest = buildTodoSet(id: 'oldest', createdAt: DateTime(2026, 1, 1));
      final middle = buildTodoSet(id: 'middle', createdAt: DateTime(2026, 2, 1));

      await repository.save(newest);
      await repository.save(oldest);
      await repository.save(middle);

      expect(repository.getAll().map((s) => s.id).toList(), ['oldest', 'middle', 'newest']);
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

  test('listenable notifies listeners when the box changes', () async {
    var notified = false;
    repository.listenable().addListener(() => notified = true);

    await repository.save(buildTodoSet(id: 'a'));
    await pumpEventQueue();

    expect(notified, isTrue);
  });
}
