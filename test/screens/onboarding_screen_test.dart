import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/screens/onboarding_screen.dart';

import '../support/hive_test_harness.dart';
import '../support/pump_helpers.dart';

// This file only exercises page-to-page navigation (via 次へ), which is
// local widget state (PageController) with no Hive write involved. It
// deliberately never taps 次へ all the way through to はじめる/スキップ and
// asserts on the result: that triggers a real Hive write from inside a
// widget callback, which — as documented throughout this test suite —
// cannot be reliably awaited in this test environment. That behavior
// (OnboardingNotifier.markSeen) is covered instead by
// providers/onboarding_providers_test.dart, a plain (non-widget) test that
// runs entirely on the real event loop.
void main() {
  final harness = HiveTestHarness();

  setUp(() => harness.setUp());
  tearDown(() => harness.tearDown());

  Future<void> pumpOnboarding(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );
    await settle(tester);
  }

  testWidgets('shows the first page\'s content and a 3-dot page indicator', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    expect(find.text('持ち物アラームへようこそ'), findsOneWidget);
    expect(find.text('次へ'), findsOneWidget);
    expect(find.text('スキップ'), findsOneWidget);
  });

  testWidgets('tapping 次へ advances through all three pages', (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('次へ'));
    await settle(tester);
    expect(find.text('セットを作って通知を設定'), findsOneWidget);
    expect(find.text('次へ'), findsOneWidget);

    await tester.tap(find.text('次へ'));
    await settle(tester);
    expect(find.text('チェックして達成感を'), findsOneWidget);
    expect(find.text('はじめる'), findsOneWidget);
    expect(find.text('スキップ'), findsNothing);
  });
}
