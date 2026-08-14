import 'package:flutter_test/flutter_test.dart';

/// Plain `pumpAndSettle()`. Safe wherever nothing being settled is itself
/// waiting on real Hive I/O to complete (dialog open/close, local
/// `setState`, a screen that was pumped after its data was already seeded
/// via `tester.runAsync()`, etc). See [tapAndWaitFor] for the case that
/// isn't safe.
Future<void> settle(WidgetTester tester) => tester.pumpAndSettle();

/// Taps [finder] and settles (see [settle]).
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await settle(tester);
}

/// Taps [finder], then waits for [condition] to become true by polling it
/// in real time via [WidgetTester.runAsync], and finally pumps once more so
/// the tree reflects the change.
///
/// Real Hive file I/O triggered from inside a widget callback (a button's
/// `onPressed`, etc.) doesn't reliably signal its own completion back to the
/// awaiting code within a `pumpAndSettle()` cycle in this test environment —
/// intermittently a single `pump()` inside it never returns, and neither
/// Flutter's own `pumpAndSettle(timeout: ...)` nor a `Future.timeout()`
/// wrapped around it are able to cut that short (the stall re-surfaces at
/// the test framework's own outstanding-async-work check). The write itself
/// does still land, though — [condition] (typically a direct, synchronous
/// repository read) polled from inside `runAsync`'s real event loop reaches
/// `true` reliably even when waiting on the tap's own Future would not.
Future<void> tapAndWaitFor(WidgetTester tester, Finder finder, bool Function() condition) async {
  await tester.tap(finder);
  await tester.pump();
  await tester.runAsync(() async {
    for (var i = 0; i < 50 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  });
  await tester.pump();
}
