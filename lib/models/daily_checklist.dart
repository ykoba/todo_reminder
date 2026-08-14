import 'package:hive/hive.dart';

part 'daily_checklist.g.dart';

/// One [DailyChecklist] represents the check state of a [TodoSet] on a single
/// calendar day, identified by [dateKey] in "yyyy-MM-dd" form (local time).
@HiveType(typeId: 3)
class DailyChecklist extends HiveObject {
  DailyChecklist({
    required this.id,
    required this.todoSetId,
    required this.dateKey,
    required this.checkedItemIds,
    this.completedAt,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String todoSetId;

  @HiveField(2)
  String dateKey;

  @HiveField(3)
  List<String> checkedItemIds;

  @HiveField(4)
  DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  bool isChecked(String itemId) => checkedItemIds.contains(itemId);
}
