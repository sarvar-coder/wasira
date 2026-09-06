import '../services/local_store.dart';

/// Preferences that outlive a launch.
class SettingsRepository {
  const SettingsRepository(this.store);

  final LocalStore store;

  /// The sizes offered for Quranic Arabic. Uthmani script at one fixed size is
  /// unreadable for a lot of people, which is why this is the one reading
  /// preference the app has.
  static const arabicSizes = [22.0, 26.0, 30.0, 34.0];
  static const defaultArabicSize = 30.0;

  /// One ayah a day, nudged five times. The count of reminders is not the
  /// count of ayahs — there is only ever one of those.
  static const reminderCount = 5;

  static const _arabicSizeKey = 'arabic_font_size';
  static const _reminderTimesKey = 'reminder_times';
  static const _translationKey = 'translation_edition';

  double get arabicFontSize {
    final stored = store.read()[_arabicSizeKey];
    final size = stored is num ? stored.toDouble() : null;
    // An unknown value falls back rather than rendering at some arbitrary size.
    return arabicSizes.contains(size) ? size! : defaultArabicSize;
  }

  void setArabicFontSize(double size) {
    if (!arabicSizes.contains(size)) return;
    store.update({_arabicSizeKey: size});
  }

  /// The translation shown under the ayah. Null until it has been chosen,
  /// which is what the picker is for.
  String? get translationEdition {
    final stored = store.read()[_translationKey];
    return stored is String && stored.isNotEmpty ? stored : null;
  }

  void setTranslationEdition(String edition) =>
      store.update({_translationKey: edition});

  /// Minutes after midnight, always [reminderCount] of them. A wall-clock time
  /// rather than an instant, so it does not shift when the device changes zone.
  List<int> get reminderTimes {
    final stored = store.read()[_reminderTimesKey];
    final parsed = stored is List
        ? [
            for (final value in stored)
              if (value is int && value >= 0 && value < 1440) value
          ]
        : const <int>[];

    final defaults = defaultReminderTimes;
    return [
      for (var i = 0; i < reminderCount; i++)
        i < parsed.length ? parsed[i] : defaults[i]
    ];
  }

  void setReminderTimes(List<int> minutes) => store.update({
        _reminderTimesKey: [
          for (final m in minutes.take(reminderCount)) m.clamp(0, 1439)
        ]
      });

  /// Spread across the waking day, so five reminders are not five
  /// notifications at once.
  static List<int> get defaultReminderTimes => [
        for (var i = 0; i < reminderCount; i++)
          8 * 60 + (12 * 60 * i) ~/ (reminderCount - 1)
      ];
}
