import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/notifications/notification_service.dart';

import '../support/fixtures.dart';
import '../support/notification_channel_mocks.dart';

/// These tests intercept the platform channels that
/// flutter_local_notifications and flutter_timezone use (see
/// support/notification_channel_mocks.dart) rather than exercising a real
/// native implementation, so they verify the business rules
/// [NotificationService] layers on top of the plugin (which weekdays get a
/// notification, what content/id/payload each one carries, when scheduling
/// is skipped) — not the plugin's own native behavior.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> log;

  setUp(() async {
    log = mockNotificationChannels();
    await NotificationService.instance.init();
    log.clear(); // only the calls made by the test body itself matter below
  });

  tearDown(teardownMockNotificationChannels);

  List<MethodCall> callsOf(String method) => log.where((call) => call.method == method).toList();

  group('scheduleForTodoSet', () {
    test('schedules exactly one notification per selected weekday', () async {
      final set = buildTodoSet(schedule: buildSchedule(repeatDays: [1, 3, 5]));

      await NotificationService.instance.scheduleForTodoSet(set);

      expect(callsOf('zonedSchedule'), hasLength(3));
    });

    test('cancels all seven weekday slots before scheduling new ones', () async {
      final set = buildTodoSet(schedule: buildSchedule(repeatDays: [1]));

      await NotificationService.instance.scheduleForTodoSet(set);

      expect(callsOf('cancel'), hasLength(7));
    });

    test('uses the set name as title, items joined by ・ as body, and the set id as payload', () async {
      final set = buildTodoSet(
        name: '保育園',
        items: [buildTodoItem(label: '連絡帳', sortOrder: 0), buildTodoItem(label: '水筒', sortOrder: 1)],
        schedule: buildSchedule(repeatDays: [1]),
      );

      await NotificationService.instance.scheduleForTodoSet(set);

      final args = callsOf('zonedSchedule').single.arguments as Map;
      expect(args['title'], '保育園');
      expect(args['body'], '連絡帳・水筒');
      expect(args['payload'], set.id);
    });

    test('orders the body by sortOrder, not by list insertion order', () async {
      final set = buildTodoSet(
        items: [buildTodoItem(label: '2番目', sortOrder: 1), buildTodoItem(label: '1番目', sortOrder: 0)],
        schedule: buildSchedule(repeatDays: [1]),
      );

      await NotificationService.instance.scheduleForTodoSet(set);

      final args = callsOf('zonedSchedule').single.arguments as Map;
      expect(args['body'], '1番目・2番目');
    });

    test('does not schedule when the set is disabled', () async {
      final set = buildTodoSet(isEnabled: false, schedule: buildSchedule(repeatDays: [1, 2]));

      await NotificationService.instance.scheduleForTodoSet(set);

      expect(callsOf('zonedSchedule'), isEmpty);
    });

    test('does not schedule when no weekdays are selected', () async {
      final set = buildTodoSet(schedule: buildSchedule(repeatDays: []));

      await NotificationService.instance.scheduleForTodoSet(set);

      expect(callsOf('zonedSchedule'), isEmpty);
    });

    test('does not schedule when the set has no items', () async {
      final set = buildTodoSet(items: [], schedule: buildSchedule(repeatDays: [1, 2]));

      await NotificationService.instance.scheduleForTodoSet(set);

      expect(callsOf('zonedSchedule'), isEmpty);
    });

    test('still cancels pending notifications even when nothing new is scheduled', () async {
      final set = buildTodoSet(isEnabled: false, schedule: buildSchedule(repeatDays: [1, 2]));

      await NotificationService.instance.scheduleForTodoSet(set);

      expect(callsOf('cancel'), hasLength(7));
      expect(callsOf('zonedSchedule'), isEmpty);
    });

    test('encodes the weekday into each notification id so ids differ across weekdays', () async {
      final set = buildTodoSet(schedule: buildSchedule(repeatDays: [1, 2, 3, 4, 5, 6, 7]));

      await NotificationService.instance.scheduleForTodoSet(set);

      final ids = callsOf('zonedSchedule').map((call) => (call.arguments as Map)['id'] as int).toList();
      expect(ids.map((id) => id % 10).toSet(), {1, 2, 3, 4, 5, 6, 7});
      expect(ids.toSet(), hasLength(7));
    });

    test('derives the same notification id for the same set+weekday across reschedules', () async {
      final set = buildTodoSet(schedule: buildSchedule(repeatDays: [3]));

      await NotificationService.instance.scheduleForTodoSet(set);
      final firstId = (callsOf('zonedSchedule').single.arguments as Map)['id'];

      log.clear();
      await NotificationService.instance.scheduleForTodoSet(set);
      final secondId = (callsOf('zonedSchedule').single.arguments as Map)['id'];

      expect(firstId, secondId);
    });
  });

  group('cancelForTodoSet', () {
    test('cancels all seven weekday slots and schedules nothing', () async {
      await NotificationService.instance.cancelForTodoSet('some-set-id');

      expect(callsOf('cancel'), hasLength(7));
      expect(callsOf('zonedSchedule'), isEmpty);
    });
  });

  group('requestPermissions', () {
    test('returns true when the platform grants permission', () async {
      final granted = await NotificationService.instance.requestPermissions();

      expect(granted, isTrue);
    });
  });

  group('getLaunchTodoSetId', () {
    test('returns null when the app was not launched via a notification', () async {
      final id = await NotificationService.instance.getLaunchTodoSetId();

      expect(id, isNull);
    });

    test('returns the payload when the app was cold-started from a notification tap', () async {
      mockNotificationChannels(launchDetails: {
        'notificationLaunchedApp': true,
        'notificationResponse': {
          'notificationId': 1,
          'actionId': null,
          'input': null,
          'notificationResponseType': 0,
          'payload': 'todo-set-7',
        },
      });

      final id = await NotificationService.instance.getLaunchTodoSetId();

      expect(id, 'todo-set-7');
    });
  });

  test('onTodoSetSelected emits the payload when a notification is tapped while running', () async {
    final received = <String>[];
    final sub = NotificationService.instance.onTodoSetSelected.listen(received.add);
    addTearDown(sub.cancel);

    await simulateNotificationTap('todo-set-42');
    await pumpEventQueue();

    expect(received, ['todo-set-42']);
  });
}
