import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/alquran_api_service.dart';
import 'data/services/local_store.dart';
import 'data/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Two small JSON files in the app's own support directory. There is no
  // database: the app remembers a translation, five reminder times, and one
  // ayah.
  final dir = await getApplicationSupportDirectory();
  final settingsStore = LocalStore(File('${dir.path}/settings.json'));
  final notifications = NotificationService();

  runApp(WasiraApp(
    api: AlquranApiService(),
    settingsStore: settingsStore,
    dailyStore: LocalStore(File('${dir.path}/daily.json')),
    notifications: notifications,
  ));

  // Deliberately not awaited: reminders are rewritten on every launch and none
  // of it needs to happen before the first frame.
  unawaited(_refreshReminders(settingsStore, notifications));
}

/// Rewrites the five daily reminders.
///
/// Skipped until a translation has been chosen: that is the moment the app
/// stops being a picker, and asking for notification permission before then
/// asks about a feature the user has not seen.
Future<void> _refreshReminders(
    LocalStore store, NotificationService notifications) async {
  try {
    final settings = SettingsRepository(store);
    if (settings.translationEdition == null) return;
    if (!await notifications.requestPermission()) return;
    await notifications.scheduleDaily(settings.reminderTimes);
  } catch (_) {
    // No reminders is a worse app, not a broken one.
  }
}
