import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/schedule.dart';
import '../models/todo_item.dart';
import '../models/todo_set.dart';
import '../notifications/notification_service.dart' show maxTimesPerDay;
import '../providers/repository_providers.dart';
import '../utils/schedule_format.dart';
import '../utils/todo_set_icons.dart';

const _uuid = Uuid();

class _EditableItem {
  _EditableItem({required this.id, required String label})
    : controller = TextEditingController(text: label);

  final String id;
  final TextEditingController controller;

  void dispose() => controller.dispose();
}

class TodoSetEditScreen extends ConsumerStatefulWidget {
  const TodoSetEditScreen({super.key, required this.todoSetId});

  /// Null when creating a new TodoSet.
  final String? todoSetId;

  @override
  ConsumerState<TodoSetEditScreen> createState() => _TodoSetEditScreenState();
}

class _TodoSetEditScreenState extends ConsumerState<TodoSetEditScreen> {
  late final TextEditingController _nameController;
  late final List<_EditableItem> _items;
  late List<TimeOfDay> _times;
  late Set<int> _repeatDays;
  late int _intervalWeeks;
  late DateTime _anchorDate;
  late bool _isEnabled;
  late final DateTime _createdAt;
  late final int _sortOrder;
  late String _icon;

  bool get _isEditing => widget.todoSetId != null;

  @override
  void initState() {
    super.initState();
    final repository = ref.read(todoSetRepositoryProvider);
    final existing = widget.todoSetId == null
        ? null
        : repository.getById(widget.todoSetId!);

    _nameController = TextEditingController(text: existing?.name ?? '');
    _items = (existing?.sortedItems ?? const <TodoItem>[])
        .map((item) => _EditableItem(id: item.id, label: item.label))
        .toList();
    _times =
        existing?.schedule.times
            .map((t) => TimeOfDay(hour: t.hour, minute: t.minute))
            .toList() ??
        [const TimeOfDay(hour: 7, minute: 0)];
    _repeatDays =
        existing?.schedule.repeatDays.toSet() ?? {1, 2, 3, 4, 5, 6, 7};
    _intervalWeeks = existing?.schedule.intervalWeeks ?? 1;
    _anchorDate = existing?.schedule.anchorDate ?? DateTime.now();
    _isEnabled = existing?.isEnabled ?? true;
    _createdAt = existing?.createdAt ?? DateTime.now();
    // New sets are appended after the current last one in the list order.
    _sortOrder = existing?.sortOrder ?? repository.getAll().length;
    _icon = existing?.icon ?? defaultTodoSetIconKey;
  }

  void _selectIcon(String key) {
    setState(() => _icon = key);
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add(_EditableItem(id: _uuid.v4(), label: '')));
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index).dispose());
  }

  void _reorderItems(int oldIndex, int newIndex) {
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  void _sortTimes() {
    _times.sort(
      (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
    );
  }

  bool _isDuplicateTime(TimeOfDay time, {int? ignoringIndex}) {
    for (var i = 0; i < _times.length; i++) {
      if (i == ignoringIndex) continue;
      if (_times[i].hour == time.hour && _times[i].minute == time.minute) {
        return true;
      }
    }
    return false;
  }

  Future<void> _addTime() async {
    if (_times.length >= maxTimesPerDay) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('通知時刻は最大$maxTimesPerDay件までです')));
      return;
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 7, minute: 0),
    );
    if (picked == null || !mounted) return;
    if (_isDuplicateTime(picked)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('その時刻はすでに追加されています')));
      return;
    }
    setState(() {
      _times.add(picked);
      _sortTimes();
    });
  }

  Future<void> _editTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times[index],
    );
    if (picked == null || !mounted) return;
    if (_isDuplicateTime(picked, ignoringIndex: index)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('その時刻はすでに追加されています')));
      return;
    }
    setState(() {
      _times[index] = picked;
      _sortTimes();
    });
  }

  void _removeTime(int index) {
    setState(() => _times.removeAt(index));
  }

  void _setIntervalWeeks(int weeks) {
    setState(() {
      // Starting a 隔週 (or wider) cadence from a 毎週 one anchors the
      // parity to "this week" rather than to whatever anchorDate was left
      // over from the set's creation, so switching it on always means "the
      // next matching day is included," matching what a user would expect.
      if (weeks != 1 && _intervalWeeks == 1) {
        _anchorDate = DateTime.now();
      }
      _intervalWeeks = weeks;
    });
  }

  void _toggleWeekday(int weekday) {
    setState(() {
      if (_repeatDays.contains(weekday)) {
        _repeatDays.remove(weekday);
      } else {
        _repeatDays.add(weekday);
      }
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('セット名を入力してください')));
      return;
    }

    if (_times.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('通知時刻を1つ以上設定してください')));
      return;
    }

    final labeledItems = <TodoItem>[];
    for (var i = 0; i < _items.length; i++) {
      final label = _items[i].controller.text.trim();
      if (label.isEmpty) continue;
      labeledItems.add(TodoItem(id: _items[i].id, label: label, sortOrder: i));
    }

    if (labeledItems.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('持ち物を1つ以上入力してください')));
      return;
    }

    final todoSet = TodoSet(
      id: widget.todoSetId ?? _uuid.v4(),
      name: name,
      items: labeledItems,
      schedule: Schedule(
        times: _times
            .map((t) => ScheduleTime(hour: t.hour, minute: t.minute))
            .toList(),
        repeatDays: _repeatDays.toList()..sort(),
        intervalWeeks: _intervalWeeks,
        anchorDate: _anchorDate,
      ),
      isEnabled: _isEnabled,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
      sortOrder: _sortOrder,
      icon: _icon,
    );

    await ref.read(todoSetRepositoryProvider).save(todoSet);
    await ref.read(notificationServiceProvider).scheduleForTodoSet(todoSet);

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('このセットを削除しますか？'),
        content: const Text('通知の予約も解除されます。この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref
        .read(notificationServiceProvider)
        .cancelForTodoSet(widget.todoSetId!);
    await ref.read(todoSetRepositoryProvider).delete(widget.todoSetId!);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'セットを編集' : 'セットを作成'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '削除',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: 'セット名',
              hintText: '例: 仕事',
            ),
          ),
          const SizedBox(height: 24),
          Text('アイコン', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final entry in todoSetIcons.entries)
                _IconOption(
                  icon: entry.value,
                  selected: entry.key == _icon,
                  onTap: () => _selectIcon(entry.key),
                ),
            ],
          ),
          const Divider(height: 32),
          Text('通知時刻', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (var i = 0; i < _times.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(formatTime(_times[i].hour, _times[i].minute)),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: '削除',
                onPressed: () => _removeTime(i),
              ),
              onTap: () => _editTime(i),
            ),
          TextButton.icon(
            onPressed: _addTime,
            icon: const Icon(Icons.add),
            label: const Text('通知時刻を追加'),
          ),
          const SizedBox(height: 16),
          Text('頻度', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('毎週')),
              ButtonSegment(value: 2, label: Text('隔週')),
            ],
            selected: {_intervalWeeks},
            onSelectionChanged: (selection) =>
                _setIntervalWeeks(selection.first),
          ),
          const SizedBox(height: 16),
          Text('曜日', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in weekdayLabels.entries)
                FilterChip(
                  label: Text(entry.value),
                  selected: _repeatDays.contains(entry.key),
                  onSelected: (_) => _toggleWeekday(entry.key),
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('通知を有効にする'),
            value: _isEnabled,
            onChanged: (value) => setState(() => _isEnabled = value),
          ),
          const Divider(height: 32),
          Text('持ち物', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            onReorderItem: _reorderItems,
            itemBuilder: (context, index) {
              final item = _items[index];
              return Padding(
                key: ValueKey(item.id),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.drag_handle),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: item.controller,
                        decoration: const InputDecoration(hintText: '例: ハンカチ'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _removeItem(index),
                    ),
                  ],
                ),
              );
            },
          ),
          TextButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add),
            label: const Text('持ち物を追加'),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }
}

class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: CircleAvatar(
        radius: 24,
        backgroundColor: selected
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
        foregroundColor: selected
            ? colorScheme.onPrimary
            : colorScheme.onSurfaceVariant,
        child: Icon(icon),
      ),
    );
  }
}
