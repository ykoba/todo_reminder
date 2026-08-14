import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/checklist_repository.dart';
import '../data/hive_boxes.dart';
import '../models/daily_checklist.dart';
import 'repository_providers.dart';

class ChecklistKey {
  const ChecklistKey({required this.todoSetId, required this.dateKey});

  final String todoSetId;
  final String dateKey;

  @override
  bool operator ==(Object other) =>
      other is ChecklistKey && other.todoSetId == todoSetId && other.dateKey == dateKey;

  @override
  int get hashCode => Object.hash(todoSetId, dateKey);
}

/// Live view of a single day's checklist. The entry must already exist
/// (via [ChecklistRepository.getOrCreate]) before this provider is watched.
final dailyChecklistProvider = StreamProvider.family<DailyChecklist?, ChecklistKey>((ref, key) {
  final repo = ref.watch(checklistRepositoryProvider);
  return _watchChecklist(repo, key.todoSetId, key.dateKey);
});

Stream<DailyChecklist?> _watchChecklist(ChecklistRepository repo, String todoSetId, String dateKey) async* {
  yield repo.get(todoSetId, dateKey);
  yield* Hive
      .box<DailyChecklist>(dailyChecklistBoxName)
      .watch()
      .map((_) => repo.get(todoSetId, dateKey));
}
