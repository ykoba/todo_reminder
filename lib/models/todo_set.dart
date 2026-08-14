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

  List<TodoItem> get sortedItems =>
      List<TodoItem>.from(items)..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}
