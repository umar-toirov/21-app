import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Daily reminders, scheduled on the phone (no server push needed).
///
/// Times are in app time, UTC+5 (Asia/Tashkent): the same clock the day closes
/// on at 23:59. Not available on web.
class ReminderService {
  ReminderService._();
  static final instance = ReminderService._();

  static const _reminders = [
    (id: 1, hour: 9, minute: 0, title: 'New day, new chance', body: 'Your Habit Zone tasks are ready. Start with one.'),
    (id: 2, hour: 20, minute: 0, title: 'Finish today\'s tasks', body: 'Keep your streak alive and earn your points.'),
    (id: 3, hour: 22, minute: 30, title: 'Day closes at 23:59', body: 'Last call. Tick off what is left before midnight.'),
  ];

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<bool> _init() async {
    if (kIsWeb) return false;
    if (_ready) return true;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ));
      _ready = true;
    } catch (_) {}
    return _ready;
  }

  /// Turns the daily reminders on (asking permission if needed) or off.
  /// Returns false if the user denied permission.
  Future<bool> sync({required bool enabled}) async {
    if (!await _init()) return false;
    try {
      await _plugin.cancelAll();
      if (!enabled) return true;

      final granted = await _plugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          await _plugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          true;
      if (!granted) return false;

      final zone = tz.getLocation('Asia/Tashkent');
      final now = tz.TZDateTime.now(zone);
      for (final r in _reminders) {
        var at = tz.TZDateTime(zone, now.year, now.month, now.day, r.hour, r.minute);
        if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          scheduledDate: at,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_reminders',
              'Daily reminders',
              channelDescription: 'Reminders to finish your daily tasks',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
