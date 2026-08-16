import 'dart:convert';

import '../models/daily_checklist.dart';
import '../models/schedule.dart';
import '../models/todo_item.dart';
import '../models/todo_set.dart';
import '../utils/todo_set_icons.dart';
import 'checklist_repository.dart';
import 'todo_set_repository.dart';

const int _backupFormatVersion = 1;

/// Serializes/restores every TodoSet and DailyChecklist as a single JSON
/// document. This app has no server, so a user-initiated local backup (via
/// the OS share sheet) is the only way to carry data across a device change
/// or reinstall — see `screens/todo_set_list_screen.dart`'s settings menu
/// for the export/import entry points.
class BackupService {
  BackupService({
    TodoSetRepository? todoSetRepository,
    ChecklistRepository? checklistRepository,
  }) : _todoSetRepository = todoSetRepository ?? TodoSetRepository(),
       _checklistRepository = checklistRepository ?? ChecklistRepository();

  final TodoSetRepository _todoSetRepository;
  final ChecklistRepository _checklistRepository;

  /// Builds a pretty-printed JSON document containing every TodoSet and
  /// DailyChecklist currently stored locally.
  String exportToJson() {
    final data = {
      'version': _backupFormatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'todoSets': _todoSetRepository.getAll().map(_todoSetToJson).toList(),
      'dailyChecklists': _checklistRepository
          .getAll()
          .map(_dailyChecklistToJson)
          .toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Replaces every locally stored TodoSet and DailyChecklist with the
  /// contents of [jsonString] (as produced by [exportToJson]).
  ///
  /// Throws a [FormatException] if [jsonString] isn't a recognizable
  /// backup — callers should show that to the user rather than silently
  /// discarding their existing data.
  Future<void> importFromJson(String jsonString) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonString);
    } on FormatException {
      throw const FormatException('バックアップファイルの形式が正しくありません');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('バックアップファイルの形式が正しくありません');
    }

    final todoSetsJson = decoded['todoSets'];
    final checklistsJson = decoded['dailyChecklists'];
    if (todoSetsJson is! List || checklistsJson is! List) {
      throw const FormatException('バックアップファイルの形式が正しくありません');
    }

    final List<TodoSet> todoSets;
    final List<DailyChecklist> checklists;
    try {
      todoSets = todoSetsJson
          .map((entry) => _todoSetFromJson(entry as Map<String, dynamic>))
          .toList();
      checklists = checklistsJson
          .map(
            (entry) => _dailyChecklistFromJson(entry as Map<String, dynamic>),
          )
          .toList();
    } on TypeError {
      throw const FormatException('バックアップファイルの形式が正しくありません');
    }

    await _todoSetRepository.replaceAll(todoSets);
    await _checklistRepository.replaceAll(checklists);
  }

  Map<String, dynamic> _todoSetToJson(TodoSet todoSet) => {
    'id': todoSet.id,
    'name': todoSet.name,
    'items': todoSet.items.map(_todoItemToJson).toList(),
    'schedule': _scheduleToJson(todoSet.schedule),
    'isEnabled': todoSet.isEnabled,
    'createdAt': todoSet.createdAt.toIso8601String(),
    'updatedAt': todoSet.updatedAt.toIso8601String(),
    'sortOrder': todoSet.sortOrder,
    'icon': todoSet.icon,
  };

  TodoSet _todoSetFromJson(Map<String, dynamic> json) => TodoSet(
    id: json['id'] as String,
    name: json['name'] as String,
    items: (json['items'] as List)
        .map((entry) => _todoItemFromJson(entry as Map<String, dynamic>))
        .toList(),
    schedule: _scheduleFromJson(json['schedule'] as Map<String, dynamic>),
    isEnabled: json['isEnabled'] as bool,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    sortOrder: json['sortOrder'] as int? ?? 0,
    icon: json['icon'] as String? ?? defaultTodoSetIconKey,
  );

  Map<String, dynamic> _todoItemToJson(TodoItem item) => {
    'id': item.id,
    'label': item.label,
    'sortOrder': item.sortOrder,
  };

  TodoItem _todoItemFromJson(Map<String, dynamic> json) => TodoItem(
    id: json['id'] as String,
    label: json['label'] as String,
    sortOrder: json['sortOrder'] as int,
  );

  Map<String, dynamic> _scheduleToJson(Schedule schedule) => {
    'hour': schedule.hour,
    'minute': schedule.minute,
    'repeatDays': schedule.repeatDays,
  };

  Schedule _scheduleFromJson(Map<String, dynamic> json) => Schedule(
    hour: json['hour'] as int,
    minute: json['minute'] as int,
    repeatDays: (json['repeatDays'] as List).cast<int>(),
  );

  Map<String, dynamic> _dailyChecklistToJson(DailyChecklist checklist) => {
    'id': checklist.id,
    'todoSetId': checklist.todoSetId,
    'dateKey': checklist.dateKey,
    'checkedItemIds': checklist.checkedItemIds,
    'completedAt': checklist.completedAt?.toIso8601String(),
    'memo': checklist.memo,
  };

  DailyChecklist _dailyChecklistFromJson(Map<String, dynamic> json) =>
      DailyChecklist(
        id: json['id'] as String,
        todoSetId: json['todoSetId'] as String,
        dateKey: json['dateKey'] as String,
        checkedItemIds: (json['checkedItemIds'] as List).cast<String>(),
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
        memo: json['memo'] as String? ?? '',
      );
}
