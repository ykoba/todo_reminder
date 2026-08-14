import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/todo_set.dart';
import '../providers/checklist_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/todo_set_providers.dart';
import '../utils/date_key.dart';
import '../utils/schedule_format.dart';
import 'checklist_screen.dart';
import 'todo_set_edit_screen.dart';

class TodoSetListScreen extends ConsumerWidget {
  const TodoSetListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todoSetsAsync = ref.watch(todoSetListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Todoリマインダー')),
      body: todoSetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('読み込みに失敗しました: $error')),
        data: (todoSets) {
          if (todoSets.isEmpty) {
            return const Center(
              child: Text('右下の + からTodoセットを作成してください'),
            );
          }
          return ListView.builder(
            itemCount: todoSets.length,
            itemBuilder: (context, index) => _TodoSetTile(todoSet: todoSets[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TodoSetEditScreen(todoSetId: null)),
        ),
        tooltip: 'Todoセットを追加',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TodoSetTile extends ConsumerWidget {
  const _TodoSetTile({required this.todoSet});

  final TodoSet todoSet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checklistAsync = ref.watch(
      dailyChecklistProvider(ChecklistKey(todoSetId: todoSet.id, dateKey: todayKey())),
    );
    final isCompletedToday = checklistAsync.valueOrNull?.isCompleted ?? false;

    return ListTile(
      title: Text(todoSet.name),
      subtitle: Text('${scheduleSummary(todoSet.schedule)} ・ ${todoSet.items.length}件'),
      leading: isCompletedToday
          ? const Icon(Icons.check_circle, color: Colors.green)
          : const Icon(Icons.circle_outlined),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: todoSet.isEnabled,
            onChanged: (enabled) async {
              todoSet.isEnabled = enabled;
              await ref.read(todoSetRepositoryProvider).save(todoSet);
              await ref.read(notificationServiceProvider).scheduleForTodoSet(todoSet);
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '編集',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TodoSetEditScreen(todoSetId: todoSet.id)),
            ),
          ),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChecklistScreen(todoSetId: todoSet.id)),
      ),
    );
  }
}
