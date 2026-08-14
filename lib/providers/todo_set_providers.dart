import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/hive_boxes.dart';
import '../data/todo_set_repository.dart';
import '../models/todo_set.dart';
import 'repository_providers.dart';

/// Live list of all TodoSets, re-emitted whenever the underlying Hive box
/// changes (create/update/delete from any screen).
final todoSetListProvider = StreamProvider<List<TodoSet>>((ref) {
  final repo = ref.watch(todoSetRepositoryProvider);
  return _watchAll(repo);
});

Stream<List<TodoSet>> _watchAll(TodoSetRepository repo) async* {
  yield repo.getAll();
  yield* Hive.box<TodoSet>(todoSetBoxName).watch().map((_) => repo.getAll());
}

/// Derives a single TodoSet from the live list so it updates reactively
/// without a second Hive subscription.
final todoSetProvider = Provider.family<TodoSet?, String>((ref, todoSetId) {
  final sets = ref.watch(todoSetListProvider).valueOrNull;
  if (sets == null) return null;
  for (final set in sets) {
    if (set.id == todoSetId) return set;
  }
  return null;
});
