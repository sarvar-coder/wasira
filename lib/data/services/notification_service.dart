import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/reminder_window.dart';

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

  /// Replaces every pending reminder with [reminders].
  ///
  /// Cancelling first is what keeps the window rolling: yesterday's leftovers
  /// go, a changed time does not leave its old copy behind, and the pending
  /// count stays under the platform cap without any bookkeeping.
  ///
  /// [textFor] returning null skips that reminder — an ayah whose text has not
  /// synced yet is better left unscheduled than sent with an empty body.
  Future<void> schedule(
    List<Reminder> reminders, {
    required ({String title, String body})? Function(int ayahNumber) textFor,
  }) async {
    await initialize();
    await _plugin.cancelAll();

    for (final reminder in reminders) {
      final text = textFor(reminder.ayahNumber);
      if (text == null) continue;

      await _plugin.zonedSchedule(
        id: reminder.id,
        scheduledDate: tz.TZDateTime.from(reminder.at, tz.local),
        title: text.title,
        body: text.body,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
