import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/schedule.dart';
import '../models/todo_set.dart';

const String _androidChannelId = 'todo_reminder_channel';
const String _androidChannelName = '持ち物アラーム';
const String _androidChannelDescription = '指定した時刻に持ち物リストを通知します';

/// Upper bounds used to size the notification-id space (see
/// [_notificationId]) and the cancellation sweep in [cancelForTodoSet]. Not
/// enforced by this class itself — [TodoSetEditScreen] is what actually
/// keeps `schedule.times` within [maxTimesPerDay].
const int maxTimesPerDay = 6;

/// How many upcoming occurrences to schedule for a 隔週 (or wider-interval)
/// schedule. Unlike a weekly (`intervalWeeks == 1`) schedule, which the OS
/// can repeat indefinitely on its own via `matchDateTimeComponents`, there's
/// no native "every N weeks" trigger, so these are individually-scheduled,
/// non-repeating notifications covering roughly the next several months.
/// [scheduleForTodoSet] is called again on every edit and on every app
/// launch (see `app.dart`) to keep this window rolling forward.
const int _biweeklyWindowCount = 8;

/// Wraps flutter_local_notifications to schedule reminders for a TodoSet's
/// (weekday × time) combinations. A TodoSet's notification content is fixed
/// at schedule time, so any edit to the set's items/times/days must go
/// through [scheduleForTodoSet] again to replace the pending notifications.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _selectedTodoSetIdController =
      StreamController<String>.broadcast();

  /// Emits a TodoSet id whenever the user taps a notification while the app
  /// process is already running (foreground or background).
  Stream<String> get onTodoSetSelected => _selectedTodoSetIdController.stream;

  Future<void> init() async {
    tz_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone.identifier));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

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
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
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
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
      return granted ?? true;
    }
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  /// Replaces all pending notifications for [todoSet] with fresh ones derived
  /// from its current items/schedule. Safe to call after any edit, and after
  /// every app launch (see `app.dart`) to keep a 隔週 schedule's rolling
  /// window of upcoming occurrences from running out.
  Future<void> scheduleForTodoSet(TodoSet todoSet) async {
    await cancelForTodoSet(todoSet.id);

    final schedule = todoSet.schedule;
    if (!todoSet.isEnabled ||
        schedule.repeatDays.isEmpty ||
        schedule.times.isEmpty ||
        todoSet.items.isEmpty) {
      return;
    }

    const body = '持ち物を確認しましょう！';
    final details = _detailsFor(body);

    for (final weekday in schedule.repeatDays) {
      for (var timeIndex = 0; timeIndex < schedule.times.length; timeIndex++) {
        final time = schedule.times[timeIndex];

        if (schedule.intervalWeeks <= 1) {
          await _plugin.zonedSchedule(
            _notificationId(todoSet.id, weekday, timeIndex, 0),
            null,
            body,
            _nextInstanceOfWeekdayTime(weekday, time.hour, time.minute),
            details,
            payload: todoSet.id,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        } else {
          final occurrences = _nextOccurrences(weekday, time, schedule);
          for (
            var occurrenceIndex = 0;
            occurrenceIndex < occurrences.length;
            occurrenceIndex++
          ) {
            await _plugin.zonedSchedule(
              _notificationId(
                todoSet.id,
                weekday,
                timeIndex,
                occurrenceIndex,
              ),
              null,
              body,
              occurrences[occurrenceIndex],
              details,
              payload: todoSet.id,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
            );
          }
        }
      }
    }
  }

  NotificationDetails _detailsFor(String body) => NotificationDetails(
    android: AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body),
    ),
    iOS: const DarwinNotificationDetails(),
  );

  Future<void> cancelForTodoSet(String todoSetId) async {
    final futures = <Future<void>>[];
    for (var weekday = 1; weekday <= 7; weekday++) {
      for (var timeIndex = 0; timeIndex < maxTimesPerDay; timeIndex++) {
        for (
          var occurrenceIndex = 0;
          occurrenceIndex < _biweeklyWindowCount;
          occurrenceIndex++
        ) {
          futures.add(
            _plugin.cancel(
              _notificationId(todoSetId, weekday, timeIndex, occurrenceIndex),
            ),
          );
        }
      }
    }
    await Future.wait(futures);
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// The next [_biweeklyWindowCount] occurrences of [weekday] at [time]
  /// that fall on a week where [schedule] is active (see
  /// [Schedule.isActiveOnWeekOf]), spaced [Schedule.intervalWeeks] apart.
  List<tz.TZDateTime> _nextOccurrences(
    int weekday,
    ScheduleTime time,
    Schedule schedule,
  ) {
    var next = _nextInstanceOfWeekdayTime(weekday, time.hour, time.minute);
    final occurrences = <tz.TZDateTime>[];
    while (occurrences.length < _biweeklyWindowCount) {
      if (schedule.isActiveOnWeekOf(next)) {
        occurrences.add(next);
        next = next.add(Duration(days: 7 * schedule.intervalWeeks));
      } else {
        next = next.add(const Duration(days: 7));
      }
    }
    return occurrences;
  }

  /// Derives a stable notification id from (todoSetId, weekday, timeIndex,
  /// occurrenceIndex). Uses a simple bounded hash rather than Dart's
  /// String.hashCode, which is not guaranteed stable across SDK versions.
  /// occurrenceIndex is always 0 for a weekly (intervalWeeks == 1) schedule,
  /// which reschedules itself natively via matchDateTimeComponents; it
  /// ranges over 0..<_biweeklyWindowCount for a 隔週+ schedule, whose
  /// occurrences are each scheduled as a separate, non-repeating alarm.
  int _notificationId(
    String todoSetId,
    int weekday,
    int timeIndex,
    int occurrenceIndex,
  ) {
    var hash = 0;
    for (final codeUnit in todoSetId.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7FFFFFFF;
    }
    return (hash % 1000000) * 1000 +
        weekday * 100 +
        timeIndex * 10 +
        occurrenceIndex;
  }
}
