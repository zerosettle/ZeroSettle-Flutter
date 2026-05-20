import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
  static const reminderNotificationId = 4201;

  /// Global once-guard for timezone-database initialization.
  /// `initializeTimeZones()` populates a process-wide database, so the guard
  /// is `static` — once any instance has initialized it, all instances see it.
  static bool _timezonesInitialized = false;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Initializes the process-wide timezone database exactly once.
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

    // Resolve the device-local timezone so reminders fire at local wall-clock
    // time. Falls back to the timezone package default (UTC) if the lookup
    // fails. This is a method-channel call, so it lives in `init()` only.
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz.identifier));
    } catch (_) {
      // Lookup failed — leave `tz.local` at its default rather than throwing.
    }

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
  /// Uses `DateTimeComponents.time` for daily recurrence. `init()` resolves
  /// `tz.local` to the device timezone via `flutter_timezone`, so the reminder
  /// fires at local wall-clock time.
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
      reminderNotificationId,
      "Don't break your streak",
      "Log today's habits before the day ends.",
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
    await _plugin.cancel(reminderNotificationId);
  }

  /// Constants surfaced for scheduling code.
  static String get androidChannelId => _androidChannelId;
}
