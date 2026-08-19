import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../models/todo_set.dart';
import '../providers/repository_providers.dart';
import '../providers/todo_set_providers.dart';
import '../utils/schedule_format.dart';
import '../utils/todo_set_icons.dart';
import 'checklist_screen.dart';
import 'settings_screen.dart';
import 'todo_set_edit_screen.dart';

class TodoSetListScreen extends ConsumerWidget {
  const TodoSetListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todoSetsAsync = ref.watch(todoSetListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('持ち物アラーム'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '設定',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
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
          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: todoSets.length,
            onReorderItem: (oldIndex, newIndex) {
              final reordered = List<TodoSet>.from(todoSets);
              reordered.insert(newIndex, reordered.removeAt(oldIndex));
              ref.read(todoSetRepositoryProvider).reorder(reordered);
            },
            itemBuilder: (context, index) {
              final todoSet = todoSets[index];
              return Slidable(
                key: ValueKey(todoSet.id),
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.25,
                  children: [
                    SlidableAction(
                      onPressed: (actionContext) {
                        Slidable.of(actionContext)?.close();
                        _deleteWithUndo(context, ref, todoSet);
                      },
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.errorContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onErrorContainer,
                      icon: Icons.delete_outline,
                    ),
                  ],
                ),
                child: _TodoSetTile(todoSet: todoSet, index: index),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const TodoSetEditScreen(todoSetId: null),
          ),
        ),
        tooltip: '持ち物セットを追加',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Ids currently mid-delete. cancelForTodoSet() sweeps hundreds of
/// notification ids one by one, which can take long enough on a real device
/// for an impatient second tap to land before the row has actually
/// disappeared — closing the slidable pane on tap already prevents that in
/// the common case, but this guard also stops a second in-flight call from
/// restarting the SnackBar's 2-second timer (which looked like the toast
/// was overstaying its duration).
final Set<String> _pendingDeleteIds = {};

/// Deletes [todoSet] (cancelling its notifications first, mirroring
/// TodoSetEditScreen's own delete flow) and offers a one-shot undo via the
/// SnackBar action rather than an upfront confirmation dialog — revealing
/// the delete button on swipe and requiring a deliberate tap is already
/// enough friction against accidental deletion.
Future<void> _deleteWithUndo(
  BuildContext context,
  WidgetRef ref,
  TodoSet todoSet,
) async {
  if (!_pendingDeleteIds.add(todoSet.id)) return;

  // Resolved up front, before any awaits: by the time cancelForTodoSet() and
  // repository.delete() below finish, this row's own BuildContext may
  // already be mid-removal (the Hive write's box.watch() stream can rebuild
  // the list — dropping this item — before this function even gets back to
  // it), which made a post-await `ScaffoldMessenger.of(context)` lookup an
  // unreliable time bomb: `context.mounted` could still read true while the
  // element was already disposing, handing back a messenger/overlay
  // reference that never actually ran the SnackBar's dismiss timer. Holding
  // the ScaffoldMessengerState itself sidesteps that entirely.
  final messenger = ScaffoldMessenger.of(context);

  try {
    final notificationService = ref.read(notificationServiceProvider);
    final repository = ref.read(todoSetRepositoryProvider);

    await notificationService.cancelForTodoSet(todoSet.id);
    await repository.delete(todoSet.id);

    messenger.showSnackBar(
      SnackBar(
        content: Text('「${todoSet.name}」を削除しました'),
        duration: const Duration(seconds: 3),
        // SnackBar defaults `persist` to true whenever it has an `action`
        // (see the framework's SnackBar constructor), which disables the
        // duration-based auto-dismiss timer entirely — the bar would then
        // only ever close via a manual tap. Explicit false restores the
        // normal timed dismissal despite the "元に戻す" action.
        persist: false,
        action: SnackBarAction(
          label: '元に戻す',
          onPressed: () async {
            await repository.save(todoSet);
            await notificationService.scheduleForTodoSet(todoSet);
          },
        ),
      ),
    );
  } finally {
    _pendingDeleteIds.remove(todoSet.id);
  }
}

/// A row shows the set's icon/name/schedule, opens the checklist on tap,
/// and always exposes a drag handle on the right for reordering — editing
/// now lives on ChecklistScreen's own app bar instead of a separate list
/// mode, so the list itself has no mode switching left.
class _TodoSetTile extends StatelessWidget {
  const _TodoSetTile({required this.todoSet, required this.index});

  final TodoSet todoSet;
  final int index;

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
      trailing: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChecklistScreen(todoSetId: todoSet.id)),
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
              'まだ持ち物セットがありません',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '右下の + から持ち物セットを作成してください',
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
