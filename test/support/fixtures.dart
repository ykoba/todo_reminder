import 'package:uuid/uuid.dart';

import 'package:todo_reminder/models/daily_checklist.dart';
import 'package:todo_reminder/models/schedule.dart';
import 'package:todo_reminder/models/todo_item.dart';
import 'package:todo_reminder/models/todo_set.dart';

const _uuid = Uuid();

TodoItem buildTodoItem({String? id, String label = 'アイテム', int sortOrder = 0}) {
  return TodoItem(id: id ?? _uuid.v4(), label: label, sortOrder: sortOrder);
}

Schedule buildSchedule({int hour = 7, int minute = 0, List<int>? repeatDays}) {
  return Schedule(hour: hour, minute: minute, repeatDays: repeatDays ?? const [1, 2, 3, 4, 5, 6, 7]);
}

TodoSet buildTodoSet({
  String? id,
  String name = 'テストセット',
  List<TodoItem>? items,
  Schedule? schedule,
  bool isEnabled = true,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final createdAtOrDefault = createdAt ?? DateTime(2026, 1, 1);
  return TodoSet(
    id: id ?? _uuid.v4(),
    name: name,
    items: items ??
        [
          buildTodoItem(label: '項目1', sortOrder: 0),
          buildTodoItem(label: '項目2', sortOrder: 1),
        ],
    schedule: schedule ?? buildSchedule(),
    isEnabled: isEnabled,
    createdAt: createdAtOrDefault,
    updatedAt: updatedAt ?? createdAtOrDefault,
  );
}

DailyChecklist buildDailyChecklist({
  String? id,
  required String todoSetId,
  required String dateKey,
  List<String>? checkedItemIds,
  DateTime? completedAt,
}) {
  return DailyChecklist(
    id: id ?? _uuid.v4(),
    todoSetId: todoSetId,
    dateKey: dateKey,
    checkedItemIds: checkedItemIds ?? <String>[],
    completedAt: completedAt,
  );
}
