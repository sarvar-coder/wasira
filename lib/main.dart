import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'app.dart';
import 'data/repositories/daily_repository.dart';
import 'data/repositories/quran_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/alquran_api_service.dart';
import 'data/services/database_service.dart';
import 'data/services/notification_service.dart';
import 'ui/onboarding/onboarding_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // One database file, in the app's own support directory. The background sync
  // isolate opens its own connection to the same path.
  final dir = await getApplicationSupportDirectory();
  final db = DatabaseService(sqlite3.open('${dir.path}/wasira.db'))..migrate();

  final notifications = NotificationService();

  runApp(WasiraApp(
    db: db,
    repository: QuranRepository(db: db, api: AlquranApiService()),
    notifications: notifications,
  ));

  // Deliberately not awaited: the window is rebuilt on every launch, and none
  // of it needs to happen before the first frame.
  unawaited(_refreshReminders(db, notifications));
}

/// Rebuilds the rolling seven-day window.
///
/// Skipped until a translation has been chosen: that is the moment the app
/// stops being a language picker, and asking for notification permission
/// before then asks about a feature the user has not seen.
Future<void> _refreshReminders(
    DatabaseService db, NotificationService notifications) async {
  try {
    await notifications.initialize();

    final edition = db.readSetting(kTranslationSetting);
    if (edition == null) return;
    if (!await notifications.requestPermission()) return;

    final daily = DailyRepository(db: db, settings: SettingsRepository(db));
    await notifications.schedule(
      daily.upcomingReminders(),
      textFor: (ayah) => daily.textFor(ayah, edition),
    );
  } catch (_) {
    // No reminders is a worse app, not a broken one.
  }
}
