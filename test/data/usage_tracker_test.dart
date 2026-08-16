import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/data/usage_tracker.dart';

import '../support/hive_test_harness.dart';

void main() {
  final harness = HiveTestHarness();
  late UsageStreakTracker tracker;

  setUp(() async {
    await harness.setUp();
    tracker = UsageStreakTracker();
  });

  tearDown(() => harness.tearDown());

  test('the first ever open starts the streak at 1', () {
    expect(tracker.recordOpenToday(now: DateTime(2026, 1, 1)), 1);
  });

  test('opening again the same day does not change the streak', () {
    tracker.recordOpenToday(now: DateTime(2026, 1, 1, 8));
    final streak = tracker.recordOpenToday(now: DateTime(2026, 1, 1, 20));

    expect(streak, 1);
  });

  test('opening on the very next calendar day extends the streak', () {
    tracker.recordOpenToday(now: DateTime(2026, 1, 1));
    tracker.recordOpenToday(now: DateTime(2026, 1, 2));
    final streak = tracker.recordOpenToday(now: DateTime(2026, 1, 3));

    expect(streak, 3);
  });

  test('skipping a day resets the streak to 1', () {
    tracker.recordOpenToday(now: DateTime(2026, 1, 1));
    tracker.recordOpenToday(now: DateTime(2026, 1, 2));
    final streak = tracker.recordOpenToday(now: DateTime(2026, 1, 4));

    expect(streak, 1);
  });
}
