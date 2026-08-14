import 'package:hive/hive.dart';

part 'todo_item.g.dart';

@HiveType(typeId: 0)
class TodoItem extends HiveObject {
  TodoItem({
    required this.id,
    required this.label,
    required this.sortOrder,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String label;

  @HiveField(2)
  int sortOrder;

  TodoItem copyWith({String? label, int? sortOrder}) {
    return TodoItem(
      id: id,
      label: label ?? this.label,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
