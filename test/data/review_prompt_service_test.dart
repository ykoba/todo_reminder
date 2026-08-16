import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/data/review_prompt_service.dart';
import 'package:todo_reminder/data/usage_tracker.dart';

import '../support/hive_test_harness.dart';

class _FakeReviewRequester implements ReviewRequester {
  _FakeReviewRequester({this.available = true});

  final bool available;
  int requestCount = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async => requestCount++;
}

void main() {
  final harness = HiveTestHarness();

  setUp(() => harness.setUp());
  tearDown(() => harness.tearDown());

  test('does not request a review before the streak reaches the threshold', () async {
    final requester = _FakeReviewRequester();
    final service = ReviewPromptService(
      usageTracker: UsageStreakTracker(),
      reviewRequester: requester,
    );

    for (var day = 1; day < reviewPromptStreakThreshold; day++) {
      await service.recordAppOpenAndMaybePromptReview(now: DateTime(2026, 1, day));
    }

    expect(requester.requestCount, 0);
  });

  test('requests a review the day the streak reaches the threshold', () async {
    final requester = _FakeReviewRequester();
    final service = ReviewPromptService(
      usageTracker: UsageStreakTracker(),
      reviewRequester: requester,
    );

    for (var day = 1; day <= reviewPromptStreakThreshold; day++) {
      await service.recordAppOpenAndMaybePromptReview(now: DateTime(2026, 1, day));
    }

    expect(requester.requestCount, 1);
  });

  test('never requests a review more than once, even across later launches', () async {
    final requester = _FakeReviewRequester();
    final service = ReviewPromptService(
      usageTracker: UsageStreakTracker(),
      reviewRequester: requester,
    );

    for (var day = 1; day <= reviewPromptStreakThreshold + 5; day++) {
      await service.recordAppOpenAndMaybePromptReview(now: DateTime(2026, 1, day));
    }

    expect(requester.requestCount, 1);
  });

  test('does not request (or mark as requested) when the review API is unavailable', () async {
    final requester = _FakeReviewRequester(available: false);
    final service = ReviewPromptService(
      usageTracker: UsageStreakTracker(),
      reviewRequester: requester,
    );

    for (var day = 1; day <= reviewPromptStreakThreshold; day++) {
      await service.recordAppOpenAndMaybePromptReview(now: DateTime(2026, 1, day));
    }

    expect(requester.requestCount, 0);
  });

  test('a broken-then-resumed streak still eventually reaches the threshold', () async {
    final requester = _FakeReviewRequester();
    final service = ReviewPromptService(
      usageTracker: UsageStreakTracker(),
      reviewRequester: requester,
    );

    // 3-day streak, then a gap, then a fresh run of 7.
    await service.recordAppOpenAndMaybePromptReview(now: DateTime(2026, 1, 1));
    await service.recordAppOpenAndMaybePromptReview(now: DateTime(2026, 1, 2));
    await service.recordAppOpenAndMaybePromptReview(now: DateTime(2026, 1, 3));
    for (var day = 10; day < 10 + reviewPromptStreakThreshold; day++) {
      await service.recordAppOpenAndMaybePromptReview(now: DateTime(2026, 1, day));
    }

    expect(requester.requestCount, 1);
  });
}
