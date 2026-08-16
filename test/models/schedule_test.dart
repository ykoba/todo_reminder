import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/models/schedule.dart';

void main() {
  group('Schedule', () {
    test('constructor assigns all fields', () {
      final schedule = Schedule(
        times: [ScheduleTime(hour: 7, minute: 30)],
        repeatDays: [1, 3, 5],
      );

      expect(schedule.times, hasLength(1));
      expect(schedule.times.single.hour, 7);
      expect(schedule.times.single.minute, 30);
      expect(schedule.repeatDays, [1, 3, 5]);
    });

    test('defaults intervalWeeks to 1 (毎週) when not given', () {
      final schedule = Schedule(
        times: [ScheduleTime(hour: 7, minute: 0)],
        repeatDays: [1],
      );

      expect(schedule.intervalWeeks, 1);
    });

    test('everyDay factory sets all seven weekdays and a single time', () {
      final schedule = Schedule.everyDay(hour: 8, minute: 15);

      expect(schedule.times, hasLength(1));
      expect(schedule.times.single.hour, 8);
      expect(schedule.times.single.minute, 15);
      expect(schedule.repeatDays, [1, 2, 3, 4, 5, 6, 7]);
    });

    test('copyWith with no arguments preserves all fields', () {
      final schedule = Schedule(
        times: [ScheduleTime(hour: 7, minute: 30)],
        repeatDays: [1, 3, 5],
        intervalWeeks: 2,
      );

      final copy = schedule.copyWith();

      expect(copy.times.single.hour, 7);
      expect(copy.repeatDays, [1, 3, 5]);
      expect(copy.intervalWeeks, 2);
    });

    test('copyWith overrides only times when given', () {
      final schedule = Schedule(
        times: [ScheduleTime(hour: 7, minute: 30)],
        repeatDays: [1, 3, 5],
      );

      final copy = schedule.copyWith(times: [ScheduleTime(hour: 20, minute: 0)]);

      expect(copy.times.single.hour, 20);
      expect(copy.repeatDays, [1, 3, 5]);
    });

    test('copyWith overrides only repeatDays when given', () {
      final schedule = Schedule(
        times: [ScheduleTime(hour: 7, minute: 30)],
        repeatDays: [1, 3, 5],
      );

      final copy = schedule.copyWith(repeatDays: [6, 7]);

      expect(copy.times.single.hour, 7);
      expect(copy.repeatDays, [6, 7]);
    });

    test('copyWith clones repeatDays so mutating the copy leaves the original untouched', () {
      final schedule = Schedule(
        times: [ScheduleTime(hour: 7, minute: 30)],
        repeatDays: [1, 3, 5],
      );

      final copy = schedule.copyWith(times: [ScheduleTime(hour: 20, minute: 0)]);
      copy.repeatDays.add(7);

      expect(schedule.repeatDays, [1, 3, 5]);
      expect(copy.repeatDays, [1, 3, 5, 7]);
    });

    group('isActiveOnWeekOf', () {
      test('is always true when intervalWeeks is 1', () {
        final schedule = Schedule(
          times: [ScheduleTime(hour: 7, minute: 0)],
          repeatDays: [1],
          anchorDate: DateTime(2026, 1, 5), // a Monday
        );

        expect(schedule.isActiveOnWeekOf(DateTime(2026, 1, 5)), isTrue);
        expect(schedule.isActiveOnWeekOf(DateTime(2026, 6, 1)), isTrue);
      });

      test('with intervalWeeks 2, the anchor week and every other week after it are active', () {
        final schedule = Schedule(
          times: [ScheduleTime(hour: 7, minute: 0)],
          repeatDays: [1],
          intervalWeeks: 2,
          anchorDate: DateTime(2026, 1, 5), // a Monday
        );

        expect(schedule.isActiveOnWeekOf(DateTime(2026, 1, 5)), isTrue); // week 0
        expect(schedule.isActiveOnWeekOf(DateTime(2026, 1, 9)), isTrue); // same week, Friday
        expect(schedule.isActiveOnWeekOf(DateTime(2026, 1, 12)), isFalse); // week 1
        expect(schedule.isActiveOnWeekOf(DateTime(2026, 1, 19)), isTrue); // week 2
      });

      test('with intervalWeeks 2, a date before the anchor still resolves correctly', () {
        final schedule = Schedule(
          times: [ScheduleTime(hour: 7, minute: 0)],
          repeatDays: [1],
          intervalWeeks: 2,
          anchorDate: DateTime(2026, 1, 19),
        );

        expect(schedule.isActiveOnWeekOf(DateTime(2026, 1, 5)), isTrue); // 2 weeks before
        expect(schedule.isActiveOnWeekOf(DateTime(2026, 1, 12)), isFalse); // 1 week before
      });
    });
  });
}
