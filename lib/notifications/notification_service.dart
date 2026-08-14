import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/todo_set.dart';

const String _androidChannelId = 'todo_reminder_channel';
const String _androidChannelName = 'Todoリマインダー';
const String _androidChannelDescription = '指定した時刻にTodoリストを通知します';

/// Wraps flutter_local_notifications to schedule one recurring notification
/// per (TodoSet, weekday) pair. A TodoSet's notification content is fixed at
/// schedule time, so any edit to the set's items/time/days must go through
/// [scheduleForTodoSet] again to replace the pending notifications.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final StreamController<String> _selectedTodoSetIdController = StreamController<String>.broadcast();

  /// Emits a TodoSet id whenever the user taps a notification while the app
  /// process is already running (foreground or background).
  Stream<String> get onTodoSetSelected => _selectedTodoSetIdController.stream;

  Future<void> init() async {
    tz_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone.identifier));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _selectedTodoSetIdController.add(payload);
        }
      },
    );

    const androidChannel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: _androidChannelDescription,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Returns the TodoSet id that launched the app from a terminated state via
  /// a notification tap, or null if the app was not launched that way.
  Future<String?> getLaunchTodoSetId() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  /// Requests notification permission (both platforms) and, on Android 12+,
  /// the exact-alarm permission needed for reminders to fire at the precise
  /// scheduled time. Returns whether notification permission was granted.
  Future<bool> requestPermissions() async {
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
      return granted ?? true;
    }
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return true;
  }

  /// Replaces all pending notifications for [todoSet] with fresh ones derived
  /// from its current items/schedule. Safe to call after any edit.
  Future<void> scheduleForTodoSet(TodoSet todoSet) async {
    await cancelForTodoSet(todoSet.id);

    if (!todoSet.isEnabled || todoSet.schedule.repeatDays.isEmpty || todoSet.items.isEmpty) {
      return;
    }

    final body = todoSet.sortedItems.map((item) => item.label).join('・');

    for (final weekday in todoSet.schedule.repeatDays) {
      await _plugin.zonedSchedule(
        _notificationId(todoSet.id, weekday),
        todoSet.name,
        body,
        _nextInstanceOfWeekdayTime(weekday, todoSet.schedule.hour, todoSet.schedule.minute),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannelId,
            _androidChannelName,
            channelDescription: _androidChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: todoSet.id,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> cancelForTodoSet(String todoSetId) async {
    for (var weekday = 1; weekday <= 7; weekday++) {
      await _plugin.cancel(_notificationId(todoSetId, weekday));
    }
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Derives a stable notification id from (todoSetId, weekday). Uses a
  /// simple bounded hash rather than Dart's String.hashCode, which is not
  /// guaranteed stable across SDK versions.
  int _notificationId(String todoSetId, int weekday) {
    var hash = 0;
    for (final codeUnit in todoSetId.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7FFFFFFF;
    }
    return (hash % 1000000) * 10 + weekday;
  }
}
