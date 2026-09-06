import '../../domain/daily_seed.dart';
import '../../domain/reminder_window.dart';
import '../services/database_service.dart';
import 'settings_repository.dart';

/// The ayahs of a day.
///
/// A day is generated on first use and then **stored**. Recomputing every time
/// would be smaller, but the pick would follow the algorithm rather than the
/// history: Dart makes no promise that `Random(seed)` yields the same stream
/// across SDK releases, and changing the count must not rewrite a day the user
/// has already read.
class DailyRepository {
  const DailyRepository({required this.db, required this.settings});

  final DatabaseService db;
  final SettingsRepository settings;

  /// Today and any day before it. A day the user missed regenerates from the
  /// seed on the spot, which is what keeps the calendar honest without storing
  /// every day up front.
  List<int> ayahsFor(DateTime date) {
    if (isFuture(date)) {
      throw ArgumentError.value(dayKey(date), 'date',
          'the ayahs of a day that has not arrived are not knowable');
    }

    final key = dayKey(date);
    final stored = db.readDailyAyahs(key);
    if (stored != null) return stored;

    final picked = dailyAyahs(
      seed: settings.dailySeed,
      date: date,
      count: settings.dailyCount,
    );
    db.writeDailyAyahs(key, picked);
    return picked;
  }

  List<int> get today => ayahsFor(DateTime.now());

  /// What a day's pick *will* be, without writing it down.
  ///
  /// Scheduling has to look ahead; history must not. A day already stored is
  /// returned as stored, so a reminder never names an ayah the day does not
  /// actually hold.
  List<int> previewFor(DateTime date) =>
      db.readDailyAyahs(dayKey(date)) ??
      dailyAyahs(
        seed: settings.dailySeed,
        date: date,
        count: settings.dailyCount,
      );

  /// The rolling window of reminders that should be pending.
  ///
  /// One per ayah per day: three ayahs a day is three notifications, not one
  /// listing three.
  List<Reminder> upcomingReminders({DateTime? from}) => reminderWindow(
        from: from ?? DateTime.now(),
        times: settings.reminderTimes,
        ayahsFor: previewFor,
      );

  /// What a reminder says. The body is the translation, so the ayah is
  /// readable from Notification Center without opening the app; with no
  /// translation chosen it falls back to the Arabic.
  ({String title, String body})? textFor(int ayahNumber, String? edition) {
    final ayah = db.readAyahsByNumber([ayahNumber]).firstOrNull;
    if (ayah == null) return null;

    final surah = db
        .readSurahs()
        .where((s) => s.number == ayah.surah)
        .firstOrNull;
    final translation = edition == null
        ? null
        : db.readTranslationsByNumber([ayahNumber], edition)[ayahNumber];

    return (
      title: '${surah?.nameEn ?? ayah.surah} ${ayah.surah}:${ayah.numberInSurah}',
      body: translation ?? ayah.textAr,
    );
  }

  /// Days already generated, newest first.
  List<String> get history => db.readDailyDates();

  /// Compared as calendar days rather than instants: a date later today is not
  /// a future day.
  static bool isFuture(DateTime date, {DateTime? now}) =>
      dayKey(date).compareTo(dayKey(now ?? DateTime.now())) > 0;
}
