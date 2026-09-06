import 'dart:math';

import '../../domain/daily_seed.dart';
import '../../domain/reciter.dart';
import '../services/database_service.dart';

/// Reading preferences that outlive a launch.
class SettingsRepository {
  const SettingsRepository(this.db);

  final DatabaseService db;

  /// The sizes offered for Quranic Arabic. Uthmani script at one fixed size is
  /// unreadable for a lot of people, which is why this is the one reading
  /// preference in v1.
  static const arabicSizes = [22.0, 26.0, 30.0, 34.0];
  static const defaultArabicSize = 30.0;

  /// How many ayahs a day offers. More than five stops being a daily habit
  /// and starts being a reading session.
  static const dailyCounts = [1, 3, 5];
  static const defaultDailyCount = 3;

  static const _arabicSizeKey = 'arabic_font_size';
  static const _reciterKey = 'reciter';
  static const _dailySeedKey = 'daily_seed';
  static const _dailyCountKey = 'daily_count';
  static const _dailySinceKey = 'daily_since';
  static const _reminderTimesKey = 'reminder_times';

  double get arabicFontSize {
    final stored = db.readSetting(_arabicSizeKey);
    final parsed = stored == null ? null : double.tryParse(stored);
    // An unknown value falls back rather than rendering at some arbitrary size.
    return arabicSizes.contains(parsed) ? parsed! : defaultArabicSize;
  }

  void setArabicFontSize(double size) {
    if (!arabicSizes.contains(size)) return;
    db.writeSetting(_arabicSizeKey, '$size');
  }

  /// Falls back to the first offered reciter when nothing is stored, or when a
  /// stored edition is no longer offered.
  Reciter get reciter {
    final stored = db.readSetting(_reciterKey);
    return Reciter.all.firstWhere(
      (r) => r.edition == stored,
      orElse: () => Reciter.all.first,
    );
  }

  void setReciter(Reciter reciter) =>
      db.writeSetting(_reciterKey, reciter.edition);

  /// Generated once and then never again — it is the whole reason a day the
  /// user missed can be reproduced rather than stored forever.
  ///
  /// Reading it the first time writes it, so the seed exists from whenever the
  /// daily feature is first touched instead of needing an install hook.
  int get dailySeed {
    final stored = int.tryParse(db.readSetting(_dailySeedKey) ?? '');
    if (stored != null) return stored;

    final seed = Random().nextInt(0x100000000);
    db.writeSetting(_dailySeedKey, '$seed');
    // Stamped alongside the seed so the calendar can stop at the day the app
    // started rather than offering a daily ayah for 2019.
    db.writeSetting(_dailySinceKey, dayKey(DateTime.now()));
    return seed;
  }

  /// The first day the calendar offers. Reading [dailySeed] is what sets it.
  DateTime get dailySince {
    final stored = db.readSetting(_dailySinceKey);
    if (stored == null) {
      dailySeed;
      return DateTime.now();
    }
    return DateTime.parse(stored);
  }

  /// One reminder per ayah, so this list is always [dailyCount] long. Stored
  /// as minutes after midnight: a wall-clock time, unaffected by the device
  /// moving between time zones.
  List<int> get reminderTimes {
    final stored = db.readSetting(_reminderTimesKey);
    final parsed = stored == null
        ? const <int>[]
        : [
            for (final part in stored.split(','))
              if (int.tryParse(part) case final int m when m >= 0 && m < 1440) m
          ];
    final defaults = defaultReminderTimes(dailyCount);
    return [
      for (var i = 0; i < dailyCount; i++)
        i < parsed.length ? parsed[i] : defaults[i]
    ];
  }

  void setReminderTimes(List<int> minutes) => db.writeSetting(
      _reminderTimesKey,
      [for (final m in minutes) m.clamp(0, 1439)].join(','));

  /// Spread across the waking day, so three reminders are morning, midday and
  /// evening rather than three notifications at once.
  static List<int> defaultReminderTimes(int count) => count <= 1
      ? const [8 * 60]
      : [for (var i = 0; i < count; i++) 8 * 60 + (12 * 60 * i) ~/ (count - 1)];

  int get dailyCount {
    final stored = int.tryParse(db.readSetting(_dailyCountKey) ?? '');
    return dailyCounts.contains(stored) ? stored! : defaultDailyCount;
  }

  void setDailyCount(int count) {
    if (!dailyCounts.contains(count)) return;
    db.writeSetting(_dailyCountKey, '$count');
  }
}

