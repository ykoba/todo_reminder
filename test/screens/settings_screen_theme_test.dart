import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/screens/settings_screen.dart';

import '../support/hive_test_harness.dart';
import '../support/pump_helpers.dart';

// Selecting a theme option triggers a real Hive disk write (persisting the
// choice) from inside the picker's onTap callback, on flutter_test's fake
// clock — the same hazard documented in todo_set_edit_screen_save_test.dart
// and useTallTestViewport's doc comment. That write's own completion can
// end up waiting on a Timer that only ever fires on the real clock, so it
// may never resolve; this file only exercises the tap itself, without
// waiting on its result, and is kept to this single test so nothing else
// in this process ever reopens a box against the now-unrecoverable Hive
// instance. Persistence itself is covered by theme_providers_test.dart's
// plain (non-widget) tests instead.
void main() {
  final harness = HiveTestHarness();

  setUp(() async {
    await harness.setUp();
  });

  testWidgets('selecting a theme option does not throw', (tester) async {
    addTearDown(harness.tearDownWithoutClosingHive);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await settle(tester);

    await tapAndSettle(tester, find.text('表示テーマ'));

    // Not awaiting the write's own completion — see the file comment above
    // for why. A single tap + pump is enough to exercise the picker's
    // selection/dismissal logic without hanging on its real Hive write.
    await tester.tap(find.text('ダーク'));
    await tester.pump();
  });
}
