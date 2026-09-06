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

  static const _arabicSizeKey = 'arabic_font_size';

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
}
