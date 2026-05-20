import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Wraps `flutter_local_notifications` setup. Reminder scheduling lives in
/// Part 2 (`scheduleEodReminder`) — this Part-1 scaffold only initializes
/// the plugin so app start-up wiring is in place.
class NotificationService {
  static const _androidChannelId = 'justone_reminders';
  static const _androidChannelName = 'JustOne reminders';
  static const _androidChannelDescription =
      'End-of-day reminders to check off your habits.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Call once during app start, BEFORE `runApp`.
  Future<void> init() async {
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

  /// Exposed so Part 2 can schedule on the same instance.
  FlutterLocalNotificationsPlugin get plugin => _plugin;

  /// Constants surfaced for Part 2's scheduling code.
  static String get androidChannelId => _androidChannelId;
}
