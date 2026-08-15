import 'dart:io';

import 'package:hive/hive.dart';

import 'package:todo_reminder/data/hive_boxes.dart';
import 'package:todo_reminder/models/daily_checklist.dart';
import 'package:todo_reminder/models/schedule.dart';
import 'package:todo_reminder/models/todo_item.dart';
import 'package:todo_reminder/models/todo_set.dart';

/// Initializes Hive against a throwaway temp directory and registers the
/// app's TypeAdapters, mirroring `initHive()` without touching the real
/// on-device data directory. Call [setUp] from a test's `setUp` and
/// [tearDown] from its `tearDown` — except a test that taps something
/// which triggers a real Hive write from inside a widget callback (an
/// `onPressed`, etc.), which must use [tearDownWithoutClosingHive] instead;
/// see that method's doc comment for why.
class HiveTestHarness {
  late Directory _tempDir;

  Future<void> setUp() async {
    _tempDir = await Directory.systemTemp.createTemp('todo_reminder_test');
    Hive.init(_tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TodoItemAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ScheduleAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TodoSetAdapter());
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(DailyChecklistAdapter());
    }

    await Hive.openBox<TodoSet>(todoSetBoxName);
    await Hive.openBox<DailyChecklist>(dailyChecklistBoxName);
    await Hive.openBox(settingsBoxName);
  }

  Future<void> tearDown() async {
    await Hive.deleteFromDisk();
    await _deleteTempDirIfPresent();
  }

  /// For the handful of tests that tap something which triggers a real
  /// Hive write from inside a widget callback. That write's own completion
  /// (a `Completer` deep in Hive's write queue) can end up waiting on a
  /// Timer that was created — and only ever fires — inside
  /// flutter_test's fake-clock zone; once the test body returns, nothing
  /// pumps that zone anymore, so the Timer never fires and the write's
  /// `Future` never resolves. `Hive.deleteFromDisk()` closes each box
  /// first, and closing awaits any in-flight write, so it inherits that
  /// same hang — deterministically, and from *any* zone, since by then the
  /// stuck dependency is that specific orphaned `Future`, not a new Timer
  /// `runAsync()` could help fire. There's no way to make Hive's own
  /// close/delete finish in this situation, so this skips it and deletes
  /// the temp directory's files directly instead. Only safe to use from a
  /// test file with exactly one test (so nothing reopens a box against
  /// this same [Hive] instance afterwards) — which every test that risks
  /// this failure mode already is, kept isolated for this exact reason.
  Future<void> tearDownWithoutClosingHive() => _deleteTempDirIfPresent();

  Future<void> _deleteTempDirIfPresent() async {
    // Hive.deleteFromDisk() already removes the directory's contents (and
    // sometimes the directory itself), so guard against a stale handle.
    if (await _tempDir.exists()) {
      await _tempDir.delete(recursive: true);
    }
  }
}
