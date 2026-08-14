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
/// [tearDown] from its `tearDown`.
class HiveTestHarness {
  late Directory _tempDir;

  Future<void> setUp() async {
    _tempDir = await Directory.systemTemp.createTemp('todo_reminder_test');
    Hive.init(_tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TodoItemAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ScheduleAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TodoSetAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(DailyChecklistAdapter());

    await Hive.openBox<TodoSet>(todoSetBoxName);
    await Hive.openBox<DailyChecklist>(dailyChecklistBoxName);
  }

  Future<void> tearDown() async {
    await Hive.deleteFromDisk();
    // Hive.deleteFromDisk() already removes the directory's contents (and
    // sometimes the directory itself), so guard against a stale handle.
    if (await _tempDir.exists()) {
      await _tempDir.delete(recursive: true);
    }
  }
}
