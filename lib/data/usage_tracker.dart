import 'package:hive/hive.dart';

import '../utils/date_key.dart';
import 'hive_boxes.dart';

const String _lastOpenedDateKeyKey = 'usageStreak.lastOpenedDateKey';
const String _streakDaysKey = 'usageStreak.days';

/// Tracks how many calendar days in a row the app has been opened,
/// persisted in the `settings` box. Used by [ReviewPromptService] to decide
/// when the user has been using the app "continuously" for about a week.
class UsageStreakTracker {
  Box get _box => Hive.box(settingsBoxName);

  /// Records that the app was opened "today" ([now], for testability —
  /// defaults to the real current time) and returns the resulting streak
  /// length. Opening more than once on the same day doesn't change it;
  /// opening after skipping a day resets it to 1.
  int recordOpenToday({DateTime? now}) {
    final today = dateKeyFor(now ?? DateTime.now());
    final lastOpened = _box.get(_lastOpenedDateKeyKey) as String?;

    if (lastOpened == today) {
      return (_box.get(_streakDaysKey) as int?) ?? 1;
    }

    final yesterday = dateKeyFor(
      (now ?? DateTime.now()).subtract(const Duration(days: 1)),
    );
    final previousStreak = (_box.get(_streakDaysKey) as int?) ?? 0;
    final streak = lastOpened == yesterday ? previousStreak + 1 : 1;

    _box.put(_lastOpenedDateKeyKey, today);
    _box.put(_streakDaysKey, streak);
    return streak;
  }
}
