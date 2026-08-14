import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_checklist.dart';
import '../models/todo_set.dart';
import '../providers/checklist_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/todo_set_providers.dart';
import '../utils/date_key.dart';
import '../utils/schedule_format.dart';
import 'checklist_history_screen.dart';

/// Opened either from a notification tap or from the TodoSet list. Shows
/// today's checklist for one TodoSet; checking items saves immediately, and
/// a "完了" button lets the user mark the day done even with items left
/// unchecked (see design: completion is a deliberate action, not an
/// automatic side effect of checking every item).
class ChecklistScreen extends ConsumerStatefulWidget {
  const ChecklistScreen({super.key, required this.todoSetId});

  final String todoSetId;

  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  late final String _dateKey;

  @override
  void initState() {
    super.initState();
    _dateKey = todayKey();
    final todoSet = ref.read(todoSetRepositoryProvider).getById(widget.todoSetId);
    if (todoSet != null) {
      ref.read(checklistRepositoryProvider).getOrCreate(todoSet, _dateKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todoSet = ref.watch(todoSetProvider(widget.todoSetId));
    if (todoSet == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final checklistAsync = ref.watch(
      dailyChecklistProvider(ChecklistKey(todoSetId: widget.todoSetId, dateKey: _dateKey)),
    );

    return checklistAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(body: Center(child: Text('エラー: $error'))),
      data: (checklist) {
        if (checklist == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return _ChecklistBody(todoSet: todoSet, checklist: checklist);
      },
    );
  }
}

class _ChecklistBody extends ConsumerWidget {
  const _ChecklistBody({required this.todoSet, required this.checklist});

  final TodoSet todoSet;
  final DailyChecklist checklist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = todoSet.sortedItems;
    final checkedCount = items.where((item) => checklist.isChecked(item.id)).length;
    final repo = ref.read(checklistRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(todoSet.name),
            Text(
              formatJapaneseDate(DateTime.now()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: '完了履歴',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChecklistHistoryScreen(todoSetId: todoSet.id)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$checkedCount/${items.length} チェック済み'),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: items.isEmpty ? 0 : checkedCount / items.length,
                ),
              ],
            ),
          ),
          if (checklist.isCompleted)
            Container(
              width: double.infinity,
              color: Colors.green.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('本日は完了しました'),
                ],
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('項目がありません'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return CheckboxListTile(
                        title: Text(item.label),
                        value: checklist.isChecked(item.id),
                        onChanged: (_) => repo.toggleItem(checklist, item.id),
                      );
                    },
                  ),
          ),
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: checklist.isCompleted
                  ? OutlinedButton(
                      onPressed: () => repo.setCompleted(checklist, false),
                      child: const Text('完了を取り消す'),
                    )
                  : FilledButton(
                      onPressed: () => repo.setCompleted(checklist, true),
                      child: const Text('完了する'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
