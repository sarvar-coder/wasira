import 'dart:math';

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
    return seed;
  }

  int get dailyCount {
    final stored = int.tryParse(db.readSetting(_dailyCountKey) ?? '');
    return dailyCounts.contains(stored) ? stored! : defaultDailyCount;
  }

  void setDailyCount(int count) {
    if (!dailyCounts.contains(count)) return;
    db.writeSetting(_dailyCountKey, '$count');
  }
}

