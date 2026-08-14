import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/todo_set.dart';
import '../providers/checklist_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/theme_providers.dart';
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
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Todoリマインダー'),
        actions: [
          PopupMenuButton<ThemeMode>(
            icon: Icon(switch (themeMode) {
              ThemeMode.light => Icons.light_mode_outlined,
              ThemeMode.dark => Icons.dark_mode_outlined,
              ThemeMode.system => Icons.brightness_auto_outlined,
            }),
            tooltip: '表示テーマ',
            onSelected: (mode) => ref.read(themeModeProvider.notifier).setThemeMode(mode),
            itemBuilder: (context) => const [
              PopupMenuItem(value: ThemeMode.system, child: Text('端末の設定に従う')),
              PopupMenuItem(value: ThemeMode.light, child: Text('ライト')),
              PopupMenuItem(value: ThemeMode.dark, child: Text('ダーク')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                formatJapaneseDate(DateTime.now()),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          Expanded(
            child: todoSetsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(child: Text('読み込みに失敗しました: $error')),
              data: (todoSets) {
                if (todoSets.isEmpty) {
                  return const Center(
                    child: Text('右下の + からTodoセットを作成してください'),
                  );
                }
                return ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: todoSets.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final reordered = List<TodoSet>.from(todoSets);
                    reordered.insert(newIndex, reordered.removeAt(oldIndex));
                    ref.read(todoSetRepositoryProvider).reorder(reordered);
                  },
                  itemBuilder: (context, index) => _TodoSetTile(
                    key: ValueKey(todoSets[index].id),
                    todoSet: todoSets[index],
                    index: index,
                  ),
                );
              },
            ),
          ),
        ],
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
  const _TodoSetTile({required super.key, required this.todoSet, required this.index});

  final TodoSet todoSet;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checklistAsync = ref.watch(
      dailyChecklistProvider(ChecklistKey(todoSetId: todoSet.id, dateKey: todayKey())),
    );
    final isCompletedToday = checklistAsync.valueOrNull?.isCompleted ?? false;

    return ListTile(
      title: Text(todoSet.name),
      subtitle: Text('${scheduleSummary(todoSet.schedule)} ・ ${todoSet.items.length}件'),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle),
          ),
          const SizedBox(width: 12),
          isCompletedToday
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const Icon(Icons.circle_outlined),
        ],
      ),
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
