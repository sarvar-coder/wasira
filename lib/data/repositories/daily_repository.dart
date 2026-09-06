import '../../domain/daily_seed.dart';
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

  /// Days already generated, newest first.
  List<String> get history => db.readDailyDates();

  /// Compared as calendar days rather than instants: a date later today is not
  /// a future day.
  static bool isFuture(DateTime date, {DateTime? now}) =>
      dayKey(date).compareTo(dayKey(now ?? DateTime.now())) > 0;
}
