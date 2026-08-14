import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/models/schedule.dart';
import 'package:todo_reminder/models/todo_item.dart';
import 'package:todo_reminder/models/todo_set.dart';

TodoSet _buildSet(List<TodoItem> items) {
  return TodoSet(
    id: 'set-1',
    name: 'テストセット',
    items: items,
    schedule: Schedule.everyDay(hour: 7, minute: 0),
    isEnabled: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('TodoSet.sortedItems', () {
    test('sorts items by sortOrder ascending regardless of insertion order', () {
      final set = _buildSet([
        TodoItem(id: 'c', label: '3番目', sortOrder: 2),
        TodoItem(id: 'a', label: '1番目', sortOrder: 0),
        TodoItem(id: 'b', label: '2番目', sortOrder: 1),
      ]);

      final sorted = set.sortedItems;

      expect(sorted.map((item) => item.id).toList(), ['a', 'b', 'c']);
    });

    test('does not mutate the underlying items list order', () {
      final original = [
        TodoItem(id: 'c', label: '3番目', sortOrder: 2),
        TodoItem(id: 'a', label: '1番目', sortOrder: 0),
      ];
      final set = _buildSet(original);

      set.sortedItems;

      expect(set.items.map((item) => item.id).toList(), ['c', 'a']);
    });

    test('returns an empty list when there are no items', () {
      final set = _buildSet([]);

      expect(set.sortedItems, isEmpty);
    });
  });
}
