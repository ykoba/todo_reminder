// Regression test for a bug that flutter test's fake-clock zone could not
// catch: SnackBar defaults its `persist` property to true whenever it has an
// `action` (see the framework's SnackBar constructor), which silently
// disables its own duration-based auto-dismiss timer — the delete-undo
// SnackBar (which has a "元に戻す" action) would then never time out on its
// own. Reproducing this needed a real device/simulator clock, hence this
// runs as an integration test rather than a widget test:
// `flutter test integration_test/delete_undo_snackbar_test.dart -d <device>`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:todo_reminder/data/hive_boxes.dart';
import 'package:todo_reminder/data/todo_set_repository.dart';
import 'package:todo_reminder/notifications/notification_service.dart';
import 'package:todo_reminder/screens/todo_set_list_screen.dart';

import '../test/support/fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('delete-undo SnackBar auto-dismisses instead of persisting', (
    tester,
  ) async {
    await initHive();
    await NotificationService.instance.init();

    final name = 'DeleteUndoSnackBarTest_${DateTime.now().millisecondsSinceEpoch}';
    await TodoSetRepository().save(buildTodoSet(name: name));

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TodoSetListScreen())),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text(name), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));

    final toastFinder = find.textContaining('を削除しました');

    // Wait for the SnackBar to appear (its own show is behind two real
    // async awaits — cancelForTodoSet and repository.delete).
    var appeared = false;
    for (var i = 0; i < 60 && !appeared; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      appeared = toastFinder.evaluate().isNotEmpty;
    }
    expect(appeared, isTrue, reason: 'SnackBar never appeared within 6s');

    // It must be gone well before this generous ceiling — its own duration
    // is 3 seconds. Getting all the way to 8s here without disappearing is
    // exactly what happens when `persist` silently defaults to true.
    var stillThere = true;
    for (var i = 0; i < 32 && stillThere; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      stillThere = toastFinder.evaluate().isNotEmpty;
    }
    expect(
      stillThere,
      isFalse,
      reason: 'SnackBar is still visible 8s after appearing — it is not '
          'auto-dismissing (check SnackBar.persist).',
    );
  });
}
