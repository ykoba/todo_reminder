import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/todo_set.dart';
import '../providers/repository_providers.dart';
import '../providers/theme_providers.dart';
import '../providers/todo_set_providers.dart';
import '../utils/schedule_format.dart';
import '../utils/todo_set_icons.dart';
import 'checklist_screen.dart';
import 'todo_set_edit_screen.dart';

enum _ListMode { normal, reordering, editing }

class TodoSetListScreen extends ConsumerStatefulWidget {
  const TodoSetListScreen({super.key});

  @override
  ConsumerState<TodoSetListScreen> createState() => _TodoSetListScreenState();
}

class _TodoSetListScreenState extends ConsumerState<TodoSetListScreen> {
  _ListMode _mode = _ListMode.normal;

  @override
  Widget build(BuildContext context) {
    final todoSetsAsync = ref.watch(todoSetListProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isNormal = _mode == _ListMode.normal;

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_mode) {
          _ListMode.reordering => '並び替え',
          _ListMode.editing => '編集',
          _ListMode.normal => 'Todoリマインダー',
        }),
        actions: isNormal
            ? [
                IconButton(
                  icon: const Icon(Icons.sort),
                  tooltip: '並び替え',
                  onPressed: () => setState(() => _mode = _ListMode.reordering),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'セットを編集',
                  onPressed: () => setState(() => _mode = _ListMode.editing),
                ),
                PopupMenuButton<ThemeMode>(
                  icon: Icon(switch (themeMode) {
                    ThemeMode.light => Icons.light_mode_outlined,
                    ThemeMode.dark => Icons.dark_mode_outlined,
                    ThemeMode.system => Icons.brightness_auto_outlined,
                  }),
                  tooltip: '表示テーマ',
                  onSelected: (mode) =>
                      ref.read(themeModeProvider.notifier).setThemeMode(mode),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: ThemeMode.system,
                      child: Text('端末の設定に従う'),
                    ),
                    PopupMenuItem(value: ThemeMode.light, child: Text('ライト')),
                    PopupMenuItem(value: ThemeMode.dark, child: Text('ダーク')),
                  ],
                ),
              ]
            : [
                TextButton(
                  onPressed: () => setState(() => _mode = _ListMode.normal),
                  child: const Text('完了'),
                ),
              ],
      ),
      body: todoSetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('読み込みに失敗しました: $error')),
        data: (todoSets) {
          if (todoSets.isEmpty) {
            return const Center(child: Text('右下の + からTodoセットを作成してください'));
          }
          if (_mode == _ListMode.reordering) {
            return ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: todoSets.length,
              onReorderItem: (oldIndex, newIndex) {
                final reordered = List<TodoSet>.from(todoSets);
                reordered.insert(newIndex, reordered.removeAt(oldIndex));
                ref.read(todoSetRepositoryProvider).reorder(reordered);
              },
              itemBuilder: (context, index) => _ReorderableTodoSetTile(
                key: ValueKey(todoSets[index].id),
                todoSet: todoSets[index],
                index: index,
              ),
            );
          }
          return ListView.builder(
            itemCount: todoSets.length,
            itemBuilder: (context, index) => _TodoSetTile(
              key: ValueKey(todoSets[index].id),
              todoSet: todoSets[index],
              isEditing: _mode == _ListMode.editing,
            ),
          );
        },
      ),
      floatingActionButton: isNormal
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TodoSetEditScreen(todoSetId: null),
                ),
              ),
              tooltip: 'Todoセットを追加',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _TodoSetTile extends StatelessWidget {
  const _TodoSetTile({
    required super.key,
    required this.todoSet,
    required this.isEditing,
  });

  final TodoSet todoSet;
  final bool isEditing;

  void _openEdit(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => TodoSetEditScreen(todoSetId: todoSet.id)),
  );

  void _openChecklist(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ChecklistScreen(todoSetId: todoSet.id)),
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      title: Text(todoSet.name),
      subtitle: Text(scheduleSummary(todoSet.schedule)),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        child: Icon(todoSetIcon(todoSet.icon), size: 20),
      ),
      trailing: isEditing
          ? IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: '編集',
              onPressed: () => _openEdit(context),
            )
          : null,
      onTap: () => isEditing ? _openEdit(context) : _openChecklist(context),
    );
  }
}

/// Simplified row shown only while reordering: just the drag handle, icon,
/// and name — the edit button/tap-to-open are hidden so they can't be
/// triggered by accident mid-drag.
class _ReorderableTodoSetTile extends StatelessWidget {
  const _ReorderableTodoSetTile({
    required super.key,
    required this.todoSet,
    required this.index,
  });

  final TodoSet todoSet;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      title: Text(todoSet.name),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        child: Icon(todoSetIcon(todoSet.icon), size: 20),
      ),
      trailing: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle),
      ),
    );
  }
}
