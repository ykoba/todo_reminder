import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/todo_set.dart';
import 'hive_boxes.dart';

class TodoSetRepository {
  Box<TodoSet> get _box => Hive.box<TodoSet>(todoSetBoxName);

  /// Notifies listeners whenever the box's contents change.
  ValueListenable<Box<TodoSet>> listenable() => _box.listenable();

  List<TodoSet> getAll() {
    final sets = _box.values.toList();
    sets.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sets;
  }

  TodoSet? getById(String id) {
    try {
      return _box.values.firstWhere((set) => set.id == id);
    } on StateError {
      return null;
    }
  }

  Future<void> save(TodoSet todoSet) => _box.put(todoSet.id, todoSet);

  Future<void> delete(String id) => _box.delete(id);

  /// Persists [orderedSets] (already in their new display order) by
  /// rewriting each one's `sortOrder` to match its position in the list.
  Future<void> reorder(List<TodoSet> orderedSets) async {
    for (var i = 0; i < orderedSets.length; i++) {
      if (orderedSets[i].sortOrder != i) {
        orderedSets[i].sortOrder = i;
        await orderedSets[i].save();
      }
    }
  }
}
