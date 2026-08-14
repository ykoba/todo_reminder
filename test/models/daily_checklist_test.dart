import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/models/daily_checklist.dart';

void main() {
  group('DailyChecklist', () {
    test('isCompleted is false when completedAt is null', () {
      final checklist = DailyChecklist(
        id: 'c-1',
        todoSetId: 'set-1',
        dateKey: '2026-01-01',
        checkedItemIds: [],
      );

      expect(checklist.isCompleted, isFalse);
    });

    test('isCompleted is true once completedAt is set', () {
      final checklist = DailyChecklist(
        id: 'c-1',
        todoSetId: 'set-1',
        dateKey: '2026-01-01',
        checkedItemIds: [],
        completedAt: DateTime(2026, 1, 1, 8),
      );

      expect(checklist.isCompleted, isTrue);
    });

    test('isChecked reflects membership in checkedItemIds', () {
      final checklist = DailyChecklist(
        id: 'c-1',
        todoSetId: 'set-1',
        dateKey: '2026-01-01',
        checkedItemIds: ['item-a'],
      );

      expect(checklist.isChecked('item-a'), isTrue);
      expect(checklist.isChecked('item-b'), isFalse);
    });
  });
}
