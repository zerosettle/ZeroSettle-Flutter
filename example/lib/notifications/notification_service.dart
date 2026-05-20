import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Wraps `flutter_local_notifications` setup and EOD reminder scheduling.
///
/// Mirrors `Reminders.kt` in the JustOne Android sample. Flutter's
/// `zonedSchedule` with `DateTimeComponents.time` is the idiomatic equivalent
/// of Android's WorkManager daily-recurrence approach.
class NotificationService {
  static const _androidChannelId = 'justone_reminders';
  static const _androidChannelName = 'JustOne reminders';
  static const _androidChannelDescription =
      'End-of-day reminders to check off your habits.';

  /// Notification ID for the EOD reminder (matches JustOne Android NOTIF_ID).
  static const _reminderNotificationId = 4201;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _timezonesInitialized = false;

  /// Ensures timezone data is initialized exactly once per instance.
  void _ensureTimeZones() {
    if (!_timezonesInitialized) {
      tzdata.initializeTimeZones();
      _timezonesInitialized = true;
    }
  }

  /// Call once during app start, BEFORE `runApp`.
  Future<void> init() async {
    // Initialize timezone data so zonedSchedule works correctly.
    _ensureTimeZones();

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _plugin.initialize(settings);

    // Register the Android notification channel up-front (no-op on iOS).
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: _androidChannelDescription,
        importance: Importance.defaultImportance,
      ),
    );
  }

  /// Schedules (or reschedules) the daily EOD reminder at [hour]:[minute]
  /// device-local time.
  ///
  /// Uses `DateTimeComponents.time` for daily recurrence. Note: `tz.local`
  /// defaults to UTC unless the host app supplies a platform-channel timezone
  /// name via `tz.setLocalLocation`. In the example app this is acceptable;
  /// production apps should set the local location using `flutter_timezone`.
  Future<void> scheduleEodReminder({int hour = 20, int minute = 0}) async {
    _ensureTimeZones();
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime.from(
      DateTime(now.year, now.month, now.day, hour, minute),
      tz.local,
    );
    // If the target time has already passed today, schedule for tomorrow.
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        channelDescription: _androidChannelDescription,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      _reminderNotificationId,
      "Don't break your streak",
      'Log today\'s habits before the day ends.',
      scheduledDate,
      notificationDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Cancels the scheduled EOD reminder.
  Future<void> cancelEodReminder() async {
    await _plugin.cancel(_reminderNotificationId);
  }

  /// Notification ID used for the EOD reminder.
  static int get reminderNotificationId => _reminderNotificationId;

  /// Exposed so Part 2 can schedule on the same instance.
  FlutterLocalNotificationsPlugin get plugin => _plugin;

  /// Constants surfaced for scheduling code.
  static String get androidChannelId => _androidChannelId;
}
