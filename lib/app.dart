import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/onboarding_providers.dart';
import 'providers/repository_providers.dart';
import 'providers/theme_providers.dart';
import 'screens/checklist_screen.dart';
import 'screens/onboarding_screen.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initNotificationHandling();
      ref.read(reviewPromptServiceProvider).recordAppOpenAndMaybePromptReview();
    });
  }

  Future<void> _initNotificationHandling() async {
    final notificationService = ref.read(notificationServiceProvider);

    await notificationService.requestPermissions();

    final launchTodoSetId = await notificationService.getLaunchTodoSetId();
    if (launchTodoSetId != null) {
      _openChecklist(launchTodoSetId);
    }

    _notificationTapSubscription = notificationService.onTodoSetSelected.listen(
      _openChecklist,
    );

    // A 隔週 (or wider-interval) schedule only has a rolling window of
    // upcoming occurrences scheduled at any time (there's no native "every
    // N weeks" OS trigger to hand indefinite recurrence off to — see
    // NotificationService.scheduleForTodoSet), so refresh every set's
    // notifications on each launch to keep that window from running out.
    for (final todoSet in ref.read(todoSetRepositoryProvider).getAll()) {
      await notificationService.scheduleForTodoSet(todoSet);
    }
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
      title: '持ち物アラーム',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ref.watch(themeModeProvider),
      home: const _AppHome(),
    );
  }
}

/// A stable widget (rather than swapping [MaterialApp.home] itself) so
/// finishing onboarding can swap to [TodoSetListScreen] in place: once the
/// initial route is built, changing what `home` evaluates to on a later
/// [MyApp] rebuild does not retroactively replace that route's content —
/// only a rebuild of an already-mounted widget (like this one, watching
/// [onboardingProvider] directly) does.
class _AppHome extends ConsumerWidget {
  const _AppHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSeenOnboarding = ref.watch(onboardingProvider);
    return hasSeenOnboarding
        ? const TodoSetListScreen()
        : const OnboardingScreen();
  }
}
