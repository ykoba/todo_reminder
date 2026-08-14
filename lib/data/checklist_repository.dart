import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/daily_checklist.dart';
import '../models/todo_set.dart';
import 'hive_boxes.dart';

const _uuid = Uuid();

class ChecklistRepository {
  Box<DailyChecklist> get _box => Hive.box<DailyChecklist>(dailyChecklistBoxName);

  static String _key(String todoSetId, String dateKey) => '${todoSetId}_$dateKey';

  ValueListenable<Box<DailyChecklist>> listenable() => _box.listenable();

  /// Returns today's [DailyChecklist] for [todoSet], creating an empty one on
  /// first access so the template ([TodoSet.items]) and the day's check
  /// state stay independent (see design: editing the template later must not
  /// corrupt past days' records).
  DailyChecklist getOrCreate(TodoSet todoSet, String dateKey) {
    final key = _key(todoSet.id, dateKey);
    final existing = _box.get(key);
    if (existing != null) return existing;

    final created = DailyChecklist(
      id: _uuid.v4(),
      todoSetId: todoSet.id,
      dateKey: dateKey,
      checkedItemIds: <String>[],
    );
    _box.put(key, created);
    return created;
  }

  DailyChecklist? get(String todoSetId, String dateKey) => _box.get(_key(todoSetId, dateKey));

  Future<void> toggleItem(DailyChecklist checklist, String itemId) async {
    final checked = checklist.checkedItemIds.contains(itemId);
    checklist.checkedItemIds = checked
        ? (List<String>.from(checklist.checkedItemIds)..remove(itemId))
        : (List<String>.from(checklist.checkedItemIds)..add(itemId));
    await checklist.save();
  }

  Future<void> setCompleted(DailyChecklist checklist, bool completed) async {
    checklist.completedAt = completed ? DateTime.now() : null;
    await checklist.save();
  }
}
