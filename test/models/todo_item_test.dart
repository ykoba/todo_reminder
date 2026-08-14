import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/models/todo_item.dart';

void main() {
  group('TodoItem', () {
    test('constructor assigns all fields', () {
      final item = TodoItem(id: 'id-1', label: '連絡帳', sortOrder: 2);

      expect(item.id, 'id-1');
      expect(item.label, '連絡帳');
      expect(item.sortOrder, 2);
    });

    test('copyWith with no arguments preserves all fields', () {
      final item = TodoItem(id: 'id-1', label: '連絡帳', sortOrder: 2);

      final copy = item.copyWith();

      expect(copy.id, item.id);
      expect(copy.label, item.label);
      expect(copy.sortOrder, item.sortOrder);
    });

    test('copyWith overrides only label when given', () {
      final item = TodoItem(id: 'id-1', label: '連絡帳', sortOrder: 2);

      final copy = item.copyWith(label: '水筒');

      expect(copy.id, 'id-1');
      expect(copy.label, '水筒');
      expect(copy.sortOrder, 2);
    });

    test('copyWith overrides only sortOrder when given', () {
      final item = TodoItem(id: 'id-1', label: '連絡帳', sortOrder: 2);

      final copy = item.copyWith(sortOrder: 5);

      expect(copy.id, 'id-1');
      expect(copy.label, '連絡帳');
      expect(copy.sortOrder, 5);
    });

    test('copyWith never changes id', () {
      final item = TodoItem(id: 'id-1', label: '連絡帳', sortOrder: 2);

      final copy = item.copyWith(label: '水筒', sortOrder: 9);

      expect(copy.id, 'id-1');
    });
  });
}
