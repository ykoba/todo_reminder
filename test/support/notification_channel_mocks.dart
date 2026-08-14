import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// Channel names used by the plugins [NotificationService] wraps. There is
/// no test-double platform implementation for these plugins, so tests that
/// exercise [NotificationService] (directly or through a screen) intercept
/// the platform channel itself and answer with benign fake responses.
const notificationMethodChannel = MethodChannel('dexterous.com/flutter/local_notifications');
const timezoneMethodChannel = MethodChannel('flutter_timezone');

/// Registers the Android platform implementation (so
/// `resolvePlatformSpecificImplementation` succeeds under `flutter test`,
/// which reports [TargetPlatform.android]) and stubs out both plugin
/// channels. Returns the call log so tests can assert on what
/// [NotificationService] sent to the platform.
///
/// [launchDetails] simulates the native response to
/// `getNotificationAppLaunchDetails` — pass a map shaped like
/// `{'notificationLaunchedApp': true, 'notificationResponse': {...}}` to
/// simulate the app being cold-started from a notification tap; omit it to
/// simulate a normal launch.
///
/// Call [teardownMockNotificationChannels] from the test's `tearDown`.
List<MethodCall> mockNotificationChannels({Map<String, dynamic>? launchDetails}) {
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  final log = <MethodCall>[];

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    notificationMethodChannel,
    (call) async {
      log.add(call);
      if (call.method == 'getNotificationAppLaunchDetails') return launchDetails;
      return true;
    },
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    timezoneMethodChannel,
    (call) async => 'UTC',
  );

  return log;
}

void teardownMockNotificationChannels() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(notificationMethodChannel, null);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(timezoneMethodChannel, null);
}

/// Simulates the native layer delivering a notification-tap event to the
/// already-running app (the `didReceiveNotificationResponse` callback that
/// `AndroidFlutterLocalNotificationsPlugin.initialize` registers on
/// [notificationMethodChannel]).
Future<void> simulateNotificationTap(String payload) async {
  final message = const StandardMethodCodec().encodeMethodCall(
    MethodCall('didReceiveNotificationResponse', <String, dynamic>{
      'notificationId': 1,
      'actionId': null,
      'input': null,
      'payload': payload,
      'notificationResponseType': 0, // NotificationResponseType.selectedNotification
    }),
  );
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(notificationMethodChannel.name, message, (_) {});
}
