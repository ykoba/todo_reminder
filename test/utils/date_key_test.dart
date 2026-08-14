import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/utils/date_key.dart';

void main() {
  group('dateKeyFor', () {
    test('formats as yyyy-MM-dd with zero-padded month and day', () {
      expect(dateKeyFor(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('formats double-digit month and day without extra padding', () {
      expect(dateKeyFor(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('ignores time-of-day, keying only on the calendar date', () {
      final morning = DateTime(2026, 8, 14, 0, 1);
      final night = DateTime(2026, 8, 14, 23, 59);

      expect(dateKeyFor(morning), dateKeyFor(night));
    });
  });

  test('todayKey matches dateKeyFor(DateTime.now())', () {
    expect(todayKey(), dateKeyFor(DateTime.now()));
  });
}
