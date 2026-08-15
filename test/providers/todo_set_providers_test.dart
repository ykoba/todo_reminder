import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/models/todo_set.dart';
import 'package:todo_reminder/providers/repository_providers.dart';
import 'package:todo_reminder/providers/todo_set_providers.dart';

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
    for (var i = 0; i < 150 && !ready(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  group('todoSetListProvider', () {
    test('starts empty when no sets exist', () async {
      final sets = await container.read(todoSetListProvider.future);

      expect(sets, isEmpty);
    });

    test(
      'reflects sets that were already saved before the first subscription',
      () async {
        await container
            .read(todoSetRepositoryProvider)
            .save(buildTodoSet(id: 'a'));

        final sets = await container.read(todoSetListProvider.future);

        expect(sets.map((s) => s.id), ['a']);
      },
    );

    test('emits an updated list after a set is saved', () async {
      // The listener must be registered before this provider is ever read
      // any other way (e.g. via `.future`): `_watchAll` is a
      // single-subscription Stream, and a prior `.future` read detaches
      // its one listener as soon as it resolves, permanently exhausting
      // the stream — no listener registered afterwards ever receives a
      // later update, no matter how long it waits.
      final events = <List<TodoSet>>[];
      final sub = container.listen(
        todoSetListProvider,
        (prev, next) => next.whenData(events.add),
      );
      addTearDown(sub.close);

      // The listener's own initial build (the current, empty list) arrives
      // asynchronously too; let it land and clear it so it isn't mistaken
      // for the update under test.
      await waitUntil(() => events.isNotEmpty);
      events.clear();

      await container
          .read(todoSetRepositoryProvider)
          .save(buildTodoSet(id: 'a'));
      await waitUntil(() => events.isNotEmpty);

      expect(events, isNotEmpty);
      expect(events.last.map((s) => s.id), contains('a'));
    });

    test('emits an updated list after a set is deleted', () async {
      await container
          .read(todoSetRepositoryProvider)
          .save(buildTodoSet(id: 'a'));

      // See the comment in the "saved" test above for why the listener
      // must be registered before any `.future` read.
      final events = <List<TodoSet>>[];
      final sub = container.listen(
        todoSetListProvider,
        (prev, next) => next.whenData(events.add),
      );
      addTearDown(sub.close);

      await waitUntil(() => events.isNotEmpty);
      events.clear();

      await container.read(todoSetRepositoryProvider).delete('a');
      await waitUntil(() => events.isNotEmpty);

      expect(events, isNotEmpty);
      expect(events.last, isEmpty);
    });
  });

  group('todoSetProvider', () {
    test('returns null before the list has loaded', () {
      expect(container.read(todoSetProvider('missing')), isNull);
    });

    test('returns null for an id that does not exist once loaded', () async {
      await container.read(todoSetListProvider.future);

      expect(container.read(todoSetProvider('missing')), isNull);
    });

    test('derives the matching set from the live list', () async {
      await container
          .read(todoSetRepositoryProvider)
          .save(buildTodoSet(id: 'a', name: 'Aセット'));
      await container.read(todoSetListProvider.future);

      expect(container.read(todoSetProvider('a'))?.name, 'Aセット');
    });

    test('updates reactively when the underlying set is edited', () async {
      await container
          .read(todoSetRepositoryProvider)
          .save(buildTodoSet(id: 'a', name: '旧名'));

      // See the comment in todoSetListProvider's "saved" test above for
      // why the listener must be registered before any `.future` read —
      // todoSetProvider derives from todoSetListProvider, so it inherits
      // the same constraint.
      final events = <TodoSet?>[];
      final sub = container.listen(
        todoSetProvider('a'),
        (prev, next) => events.add(next),
      );
      addTearDown(sub.close);

      await waitUntil(() => events.isNotEmpty);
      events.clear();

      await container
          .read(todoSetRepositoryProvider)
          .save(buildTodoSet(id: 'a', name: '新名'));
      await waitUntil(() => events.isNotEmpty);

      expect(events, isNotEmpty);
      expect(events.last?.name, '新名');
    });
  });
}
