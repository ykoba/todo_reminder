import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/providers/theme_providers.dart';

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

  test('defaults to ThemeMode.system when nothing has been saved yet', () {
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('setThemeMode updates the live state', () async {
    await container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);

    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  test('setThemeMode persists the choice for a later container (app restart)', () async {
    await container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);

    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);

    expect(restarted.read(themeModeProvider), ThemeMode.light);
  });

  test('setThemeMode back to system persists as system, not the last non-system value', () async {
    await container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
    await container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);

    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);

    expect(restarted.read(themeModeProvider), ThemeMode.system);
  });
}
