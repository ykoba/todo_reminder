import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/hive_boxes.dart';

const String _hasSeenOnboardingKey = 'hasSeenOnboarding';

/// Whether the user has completed the first-run onboarding flow, persisted
/// in Hive so it's only ever shown once per install.
class OnboardingNotifier extends Notifier<bool> {
  Box get _box => Hive.box(settingsBoxName);

  @override
  bool build() => (_box.get(_hasSeenOnboardingKey) as bool?) ?? false;

  Future<void> markSeen() async {
    state = true;
    await _box.put(_hasSeenOnboardingKey, true);
  }
}

final onboardingProvider = NotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);
