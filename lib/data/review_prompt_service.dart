import 'package:hive/hive.dart';
import 'package:in_app_review/in_app_review.dart';

import 'hive_boxes.dart';
import 'usage_tracker.dart';

/// How many consecutive days of app use trigger the store-review prompt.
/// "About a week" of continuous, habitual use is a reasonable, non-pushy
/// signal that the user has gotten real value out of the app.
const int reviewPromptStreakThreshold = 7;

const String _hasRequestedReviewKey = 'usageStreak.hasRequestedReview';

/// Thin wrapper around [InAppReview] so [ReviewPromptService] can be tested
/// without the plugin's platform channel (there's no bundled test double,
/// unlike e.g. package_info_plus's `setMockInitialValues`).
abstract class ReviewRequester {
  Future<bool> isAvailable();
  Future<void> requestReview();
}

class _PluginReviewRequester implements ReviewRequester {
  @override
  Future<bool> isAvailable() => InAppReview.instance.isAvailable();

  @override
  Future<void> requestReview() => InAppReview.instance.requestReview();
}

/// Decides when to ask the user for a store review: the first time they've
/// opened the app on [reviewPromptStreakThreshold] consecutive calendar
/// days, and never again after that (regardless of streaks broken or
/// resumed later).
class ReviewPromptService {
  ReviewPromptService({
    UsageStreakTracker? usageTracker,
    ReviewRequester? reviewRequester,
  }) : _usageTracker = usageTracker ?? UsageStreakTracker(),
       _reviewRequester = reviewRequester ?? _PluginReviewRequester();

  final UsageStreakTracker _usageTracker;
  final ReviewRequester _reviewRequester;

  Box get _box => Hive.box(settingsBoxName);

  /// Call once per app launch. Records today's usage and, if the streak has
  /// just reached the threshold for the first time, asks the OS to show its
  /// native store-review prompt.
  Future<void> recordAppOpenAndMaybePromptReview({DateTime? now}) async {
    final streak = _usageTracker.recordOpenToday(now: now);

    final alreadyRequested =
        (_box.get(_hasRequestedReviewKey) as bool?) ?? false;
    if (alreadyRequested || streak < reviewPromptStreakThreshold) return;

    if (!await _reviewRequester.isAvailable()) return;
    await _reviewRequester.requestReview();
    await _box.put(_hasRequestedReviewKey, true);
  }
}
