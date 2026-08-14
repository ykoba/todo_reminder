import 'package:hive_flutter/hive_flutter.dart';

import '../models/daily_checklist.dart';
import '../models/schedule.dart';
import '../models/todo_item.dart';
import '../models/todo_set.dart';

const String todoSetBoxName = 'todo_sets';
const String dailyChecklistBoxName = 'daily_checklists';

Future<void> initHive() async {
  await Hive.initFlutter();

  Hive.registerAdapter(TodoItemAdapter());
  Hive.registerAdapter(ScheduleAdapter());
  Hive.registerAdapter(TodoSetAdapter());
  Hive.registerAdapter(DailyChecklistAdapter());

  await Hive.openBox<TodoSet>(todoSetBoxName);
  await Hive.openBox<DailyChecklist>(dailyChecklistBoxName);
}
