import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/todo_set.dart';
import '../providers/repository_providers.dart';
import '../providers/todo_set_providers.dart';
import '../utils/schedule_format.dart';
import '../utils/todo_set_icons.dart';
import 'checklist_screen.dart';
import 'settings_screen.dart';
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
    final isNormal = _mode == _ListMode.normal;

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_mode) {
          _ListMode.reordering => '並び替え',
          _ListMode.editing => '編集',
          _ListMode.normal => '持ち物アラーム',
        }),
        actions: isNormal
            ? [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: '設定',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
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
            return const _EmptyState();
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
      // Sort/edit sit as smaller satellite FABs stacked above the main add
      // FAB — the common Material pattern for a couple of secondary actions
      // clustered around a screen's primary action — rather than as AppBar
      // icons, which were competing for attention with the app title.
      floatingActionButton: isNormal
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'reorder',
                  onPressed: () => setState(() => _mode = _ListMode.reordering),
                  tooltip: '並び替え',
                  child: const Icon(Icons.sort),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'edit',
                  onPressed: () => setState(() => _mode = _ListMode.editing),
                  tooltip: 'セットを編集',
                  child: const Icon(Icons.edit_outlined),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'add',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TodoSetEditScreen(todoSetId: null),
                    ),
                  ),
                  tooltip: 'Todoセットを追加',
                  child: const Icon(Icons.add),
                ),
              ],
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

/// Friendly illustration (rather than bare instructional text) shown when
/// there are no TodoSets yet — a first-impression moment for new users.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primaryContainer,
                    ),
                  ),
                  Icon(
                    Icons.checklist_rtl_rounded,
                    size: 84,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  Positioned(
                    right: 12,
                    top: 20,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.secondaryContainer,
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'まだTodoセットがありません',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '右下の + からTodoセットを作成してください',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
