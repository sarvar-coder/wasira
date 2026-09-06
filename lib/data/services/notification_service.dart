import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;


/// Schedules the daily ayah reminders.
///
/// Holds no state beyond the plugin: the window is recomputed from the seed
/// and rewritten wholesale, so there is nothing here to fall out of step with
/// what is actually pending.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;

  static const _details = NotificationDetails(
    macOS: DarwinNotificationDetails(),
    iOS: DarwinNotificationDetails(),
    android: AndroidNotificationDetails(
      'daily_ayah',
      'Daily ayah',
      channelDescription: 'The ayahs of the day, at the times you chose',
      importance: Importance.defaultImportance,
    ),
  );

  /// Loads the zone database and points it at the device's own zone. Without
  /// this every reminder would be scheduled in UTC, which for Tashkent is five
  /// hours out.
  /// Safe to call more than once: the daily screen reschedules through this
  /// service and cannot know whether launch got here first.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(_localLocation());

    await _plugin.initialize(
        settings: const InitializationSettings(
        macOS: DarwinInitializationSettings(
        // Asked for explicitly, when the user turns reminders on, rather than
        // at first launch before they know what the app is.
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
      ),
        iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
      ),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  /// The IANA zone name, read from the symlink the OS already maintains —
  /// `/etc/localtime` points at the zoneinfo file, so no package is needed to
  /// ask what zone this is.
  //
  // ponytail: macOS and Linux only. Windows keeps its zone in the registry
  // under a different naming scheme; add a lookup when Windows ships.
  static tz.Location _localLocation() {
    try {
      final target = Link('/etc/localtime').targetSync();
      final marker = target.indexOf('zoneinfo/');
      if (marker >= 0) {
        return tz.getLocation(target.substring(marker + 'zoneinfo/'.length));
      }
    } catch (_) {
      // An unreadable link or an unknown zone name both mean the same thing.
    }
    return tz.UTC;
  }

  /// Whether the user allows reminders. Returns false when they decline, which
  /// is a settled answer rather than an error.
  Future<bool> requestPermission() async {
    if (Platform.isMacOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, sound: true) ??
          false;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, sound: true) ??
          false;
    }
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    return false;
  }

  /// Rewrites the day's reminders: one repeating notification per time in
  /// [minutes], each firing at that wall-clock time every day.
  ///
  /// Repeating rather than scheduled ahead, because there is no ahead — the
  /// app only ever knows today's ayah, so a notification cannot carry its text
  /// and there is nothing to recompute each morning. Five pending
  /// notifications, forever, well inside every platform's cap.
  ///
  /// Cancelling first is what keeps a changed time from leaving its old copy
  /// behind.
  Future<void> scheduleDaily(List<int> minutes) async {
    await initialize();
    await _plugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);

    for (var slot = 0; slot < minutes.length; slot++) {
      final at = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        minutes[slot] ~/ 60,
        minutes[slot] % 60,
      );

      await _plugin.zonedSchedule(
        id: slot,
        // A time already past today starts tomorrow rather than firing the
        // moment it is scheduled, which reads as a bug rather than a reminder.
        scheduledDate:
            at.isAfter(now) ? at : at.add(const Duration(days: 1)),
        title: _title,
        body: _body,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  /// Fixed text. A repeating notification carries the same body every day,
  /// and the ayah changes daily, so naming it would mean knowing tomorrow's —
  /// which is the one thing this app deliberately does not do.
  static const _title = 'Wasira';
  static const _body = "Today's ayah is ready";

  Future<void> cancelAll() => _plugin.cancelAll();
}
