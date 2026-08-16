import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/providers/onboarding_providers.dart';

import '../support/hive_test_harness.dart';

void main() {
  final harness = HiveTestHarness();
  late ProviderContainer container;

  setUp(() async {
    await harness.setUp();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  tearDown(() => harness.tearDown());

  test('defaults to false (not seen) when nothing has been saved yet', () {
    expect(container.read(onboardingProvider), isFalse);
  });

  test('markSeen updates the live state', () async {
    await container.read(onboardingProvider.notifier).markSeen();

    expect(container.read(onboardingProvider), isTrue);
  });

  test('markSeen persists for a later container (app restart)', () async {
    await container.read(onboardingProvider.notifier).markSeen();

    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);

    expect(restarted.read(onboardingProvider), isTrue);
  });
}
