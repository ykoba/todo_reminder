import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/models/schedule.dart';

void main() {
  group('Schedule', () {
    test('constructor assigns all fields', () {
      final schedule = Schedule(hour: 7, minute: 30, repeatDays: [1, 3, 5]);

      expect(schedule.hour, 7);
      expect(schedule.minute, 30);
      expect(schedule.repeatDays, [1, 3, 5]);
    });

    test('everyDay factory sets all seven weekdays', () {
      final schedule = Schedule.everyDay(hour: 8, minute: 15);

      expect(schedule.hour, 8);
      expect(schedule.minute, 15);
      expect(schedule.repeatDays, [1, 2, 3, 4, 5, 6, 7]);
    });

    test('copyWith with no arguments preserves all fields', () {
      final schedule = Schedule(hour: 7, minute: 30, repeatDays: [1, 3, 5]);

      final copy = schedule.copyWith();

      expect(copy.hour, 7);
      expect(copy.minute, 30);
      expect(copy.repeatDays, [1, 3, 5]);
    });

    test('copyWith overrides only hour when given', () {
      final schedule = Schedule(hour: 7, minute: 30, repeatDays: [1, 3, 5]);

      final copy = schedule.copyWith(hour: 20);

      expect(copy.hour, 20);
      expect(copy.minute, 30);
      expect(copy.repeatDays, [1, 3, 5]);
    });

    test('copyWith overrides only repeatDays when given', () {
      final schedule = Schedule(hour: 7, minute: 30, repeatDays: [1, 3, 5]);

      final copy = schedule.copyWith(repeatDays: [6, 7]);

      expect(copy.hour, 7);
      expect(copy.minute, 30);
      expect(copy.repeatDays, [6, 7]);
    });

    test('copyWith clones repeatDays so mutating the copy leaves the original untouched', () {
      final schedule = Schedule(hour: 7, minute: 30, repeatDays: [1, 3, 5]);

      final copy = schedule.copyWith(hour: 20);
      copy.repeatDays.add(7);

      expect(schedule.repeatDays, [1, 3, 5]);
      expect(copy.repeatDays, [1, 3, 5, 7]);
    });
  });
}
