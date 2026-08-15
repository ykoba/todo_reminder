import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/repository_providers.dart';
import 'providers/theme_providers.dart';
import 'screens/checklist_screen.dart';
import 'screens/todo_set_list_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  StreamSubscription<String>? _notificationTapSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initNotificationHandling());
  }

  Future<void> _initNotificationHandling() async {
    final notificationService = ref.read(notificationServiceProvider);

    await notificationService.requestPermissions();

    final launchTodoSetId = await notificationService.getLaunchTodoSetId();
    if (launchTodoSetId != null) {
      _openChecklist(launchTodoSetId);
    }

    _notificationTapSubscription = notificationService.onTodoSetSelected.listen(_openChecklist);
  }

  void _openChecklist(String todoSetId) {
    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => ChecklistScreen(todoSetId: todoSetId)),
    );
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: '持ち物リマインダー',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
      ),
      themeMode: ref.watch(themeModeProvider),
      home: const TodoSetListScreen(),
    );
  }
}
