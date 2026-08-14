import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/models/schedule.dart';
import 'package:todo_reminder/utils/schedule_format.dart';

void main() {
  test('weekdayLabels maps DateTime.weekday (1=Mon..7=Sun) to single-character Japanese labels', () {
    expect(weekdayLabels, {
      1: '月',
      2: '火',
      3: '水',
      4: '木',
      5: '金',
      6: '土',
      7: '日',
    });
  });

  group('formatTime', () {
    test('zero-pads single-digit hour and minute', () {
      expect(formatTime(7, 5), '07:05');
    });

    test('leaves double-digit hour and minute as-is', () {
      expect(formatTime(23, 59), '23:59');
    });

    test('formats midnight as 00:00', () {
      expect(formatTime(0, 0), '00:00');
    });
  });

  group('scheduleSummary', () {
    test('shows 毎日 when all seven weekdays are selected', () {
      final schedule = Schedule(hour: 7, minute: 0, repeatDays: [1, 2, 3, 4, 5, 6, 7]);

      expect(scheduleSummary(schedule), '毎日 07:00');
    });

    test('shows 未設定 when no weekdays are selected', () {
      final schedule = Schedule(hour: 7, minute: 0, repeatDays: []);

      expect(scheduleSummary(schedule), '未設定 07:00');
    });

    test('lists selected weekdays sorted, regardless of input order', () {
      final schedule = Schedule(hour: 18, minute: 30, repeatDays: [5, 1, 3]);

      expect(scheduleSummary(schedule), '月水金 18:30');
    });

    test('a single selected weekday shows just that day', () {
      final schedule = Schedule(hour: 9, minute: 0, repeatDays: [7]);

      expect(scheduleSummary(schedule), '日 09:00');
    });
  });

  test('formatJapaneseDate shows M/d（曜） using the known Monday 2024-01-01', () {
    expect(formatJapaneseDate(DateTime(2024, 1, 1)), '1/1（月）');
  });
}
