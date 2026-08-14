import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:todo_reminder/data/hive_boxes.dart';
import 'package:todo_reminder/models/daily_checklist.dart';
import 'package:todo_reminder/models/schedule.dart';
import 'package:todo_reminder/models/todo_item.dart';
import 'package:todo_reminder/models/todo_set.dart';
import 'package:todo_reminder/screens/todo_set_list_screen.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('todo_reminder_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TodoItemAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ScheduleAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TodoSetAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(DailyChecklistAdapter());
    await Hive.openBox<TodoSet>(todoSetBoxName);
    await Hive.openBox<DailyChecklist>(dailyChecklistBoxName);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  testWidgets('shows empty state when no TodoSets exist', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: TodoSetListScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('右下の + からTodoセットを作成してください'), findsOneWidget);
  });
}
