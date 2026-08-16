import 'package:hive_flutter/hive_flutter.dart';

import '../models/daily_checklist.dart';
import '../models/schedule.dart';
import '../models/todo_item.dart';
import '../models/todo_set.dart';

const String todoSetBoxName = 'todo_sets';
const String dailyChecklistBoxName = 'daily_checklists';
const String settingsBoxName = 'settings';

Future<void> initHive() async {
  await Hive.initFlutter();

  Hive.registerAdapter(TodoItemAdapter());
  Hive.registerAdapter(ScheduleAdapter());
  Hive.registerAdapter(TodoSetAdapter());
  Hive.registerAdapter(DailyChecklistAdapter());
  Hive.registerAdapter(ScheduleTimeAdapter());

  await Hive.openBox<TodoSet>(todoSetBoxName);
  await Hive.openBox<DailyChecklist>(dailyChecklistBoxName);
  await Hive.openBox(settingsBoxName);
}
