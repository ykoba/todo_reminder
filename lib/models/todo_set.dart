import 'package:hive/hive.dart';

import 'schedule.dart';
import 'todo_item.dart';

part 'todo_set.g.dart';

@HiveType(typeId: 2)
class TodoSet extends HiveObject {
  TodoSet({
    required this.id,
    required this.name,
    required this.items,
    required this.schedule,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
    required this.sortOrder,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<TodoItem> items;

  @HiveField(3)
  Schedule schedule;

  @HiveField(4)
  bool isEnabled;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  /// Manual ordering for the TodoSet list (lower sorts first). Sets created
  /// before this field existed default to 0 on read.
  @HiveField(7, defaultValue: 0)
  int sortOrder;

  List<TodoItem> get sortedItems =>
      List<TodoItem>.from(items)..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}
