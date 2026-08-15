import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plain `pumpAndSettle()`. Safe wherever nothing being settled is itself
/// waiting on real Hive I/O to complete (dialog open/close, local
/// `setState`, a screen that was pumped after its data was already seeded
/// via `tester.runAsync()`, etc). Not safe after a tap that triggers a real
/// Hive write from inside a widget callback — see [useTallTestViewport]'s
/// doc comment for why no combination of pumping/polling/`runAsync` can
/// make waiting on that write's own completion reliable in this test
/// environment; such taps should be fired without waiting on their result.
Future<void> settle(WidgetTester tester) => tester.pumpAndSettle();

/// Taps [finder] and settles (see [settle]).
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await settle(tester);
}

/// Grows the test surface tall enough that TodoSetEditScreen's whole form —
/// including the "保存" button at the very bottom — fits without scrolling.
///
/// The default 800x600 test surface is no longer enough to fit the form
/// since the icon picker made it taller, so a `ListView` sliver only builds
/// the (now off-screen) "保存" button once scrolled into its render/cache
/// extent. Scrolling to it first (a drag gesture) then tapping it works for
/// taps that don't trigger a real Hive write; for ones that do, avoiding
/// the scroll — by giving the form enough room that it was never needed —
/// keeps the tap identical to a plain, unscrolled one. Restored via
/// `addTearDown`.
///
/// A real Hive write triggered from inside a widget callback runs on
/// flutter_test's fake clock, but the write's own completion (an internal
/// Hive Timer) only ever fires on the real one — outside
/// `tester.runAsync()`, nothing advances it — so no amount of
/// pumping/polling/timeout after such a tap can reliably observe that
/// write finishing; it can hang the test indefinitely. Fire such taps with
/// a single `tester.tap()` + `tester.pump()` and don't assert on anything
/// downstream of the write (its persisted data, or even whether the screen
/// navigated away) — assert on it via a plain (non-widget) test instead,
/// which runs in the real zone throughout.
void useTallTestViewport(WidgetTester tester) {
  final view = tester.view;
  final originalSize = view.physicalSize;
  final originalDevicePixelRatio = view.devicePixelRatio;
  view.physicalSize = const Size(800, 2400);
  view.devicePixelRatio = 1.0;
  addTearDown(() {
    view.physicalSize = originalSize;
    view.devicePixelRatio = originalDevicePixelRatio;
  });
}
