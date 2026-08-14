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
    sets.sort((a, b) => a.createdAt.compareTo(b.createdAt));
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
}
