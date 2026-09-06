import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wasira/data/repositories/daily_repository.dart';
import 'package:wasira/data/repositories/settings_repository.dart';
import 'package:wasira/data/services/database_service.dart';
import 'package:wasira/domain/daily_seed.dart';
import 'package:wasira/domain/models/ayah.dart';
import 'package:wasira/domain/models/surah.dart';
import 'package:wasira/domain/reminder_window.dart';

void main() {
  // Three reminders a day: morning, midday, evening.
  const times = [8 * 60, 14 * 60, 20 * 60];

  /// A day whose ayahs are its day-of-month, so assertions can name them.
  List<int> ayahsOf(DateTime day) => [day.day, day.day + 1, day.day + 2];

  group('the window', () {
    test('covers seven days, one reminder per ayah', () {
      // 06:00, so nothing today has passed yet.
      final window = reminderWindow(
        from: DateTime(2026, 9, 6, 6),
        times: times,
        ayahsFor: ayahsOf,
      );

      expect(window, hasLength(7 * 3));
      expect(window.first.at, DateTime(2026, 9, 6, 8));
      expect(window.last.at, DateTime(2026, 9, 12, 20));
    });

    test('stays well inside the platform cap at the largest count', () {
      // macOS keeps about 64 pending notifications and drops the rest.
      final window = reminderWindow(
        from: DateTime(2026, 9, 6, 6),
        times: const [8 * 60, 11 * 60, 14 * 60, 17 * 60, 20 * 60],
        ayahsFor: (d) => [for (var i = 0; i < 5; i++) d.day + i],
      );

      expect(window, hasLength(35));
      expect(window.length, lessThan(64));
    });

    test('skips times already gone today rather than firing on the spot', () {
      final window = reminderWindow(
        from: DateTime(2026, 9, 6, 15),
        times: times,
        ayahsFor: ayahsOf,
      );

      // Today keeps only 20:00; the six other days keep all three.
      expect(window, hasLength(1 + 6 * 3));
      expect(window.first.at, DateTime(2026, 9, 6, 20));
    });

    test('a reminder due this minute is treated as gone', () {
      final window = reminderWindow(
        from: DateTime(2026, 9, 6, 8),
        times: const [8 * 60],
        ayahsFor: ayahsOf,
      );

      expect(window.first.at, DateTime(2026, 9, 7, 8));
    });

    test('crosses a month end', () {
      final window = reminderWindow(
        from: DateTime(2026, 9, 28, 6),
        times: const [8 * 60],
        ayahsFor: ayahsOf,
      );

      expect(window.map((r) => r.at).toList(), [
        DateTime(2026, 9, 28, 8),
        DateTime(2026, 9, 29, 8),
        DateTime(2026, 9, 30, 8),
        DateTime(2026, 10, 1, 8),
        DateTime(2026, 10, 2, 8),
        DateTime(2026, 10, 3, 8),
        DateTime(2026, 10, 4, 8),
      ]);
    });

    test('keeps the wall-clock time, so a zone shift does not move it', () {
      // Built from date parts rather than added as a Duration: adding 8 hours
      // to midnight lands at 07:00 on a day the clock springs forward.
      final window = reminderWindow(
        from: DateTime(2026, 3, 27, 6),
        times: const [8 * 60],
        ayahsFor: ayahsOf,
        days: 3,
      );

      expect(window.every((r) => r.at.hour == 8 && r.at.minute == 0), isTrue);
    });

    test('pairs slot with ayah, so each reminder names a different one', () {
      final window = reminderWindow(
        from: DateTime(2026, 9, 6, 6),
        times: times,
        ayahsFor: ayahsOf,
        days: 1,
      );

      expect(window.map((r) => r.ayahNumber), [6, 7, 8]);
    });

    test('a day with fewer ayahs than times schedules only what it has', () {
      final window = reminderWindow(
        from: DateTime(2026, 9, 6, 6),
        times: times,
        ayahsFor: (_) => [42],
        days: 1,
      );

      expect(window, hasLength(1));
    });
  });

  group('reminder ids', () {
    test('are stable, so rescheduling replaces rather than duplicates', () {
      expect(reminderId(DateTime(2026, 9, 6), 0),
          reminderId(DateTime(2026, 9, 6, 23, 59), 0));
    });

    test('are distinct across days and slots', () {
      final ids = {
        for (var d = 0; d < 400; d++)
          for (var slot = 0; slot < 5; slot++)
            reminderId(DateTime(2026, 1, 1).add(Duration(days: d)), slot),
      };
      expect(ids, hasLength(400 * 5));
    });

    test('fit in the 32-bit id the platforms expect', () {
      for (final year in [2026, 2050]) {
        expect(reminderId(DateTime(year, 12, 31), 7), lessThan(1 << 31));
      }
    });
  });

  group('scheduling ahead of the day', () {
    late Database raw;
    late DatabaseService db;
    late DailyRepository daily;

    setUp(() {
      raw = sqlite3.openInMemory();
      db = DatabaseService(raw)..migrate();
      db.writeSurahs([
        const Surah(
          number: 1,
          nameAr: 'الفاتحة',
          nameEn: 'Al-Faatiha',
          nameEnTranslation: 'The Opening',
          revelationType: 'Meccan',
          ayahCount: 7,
        ),
      ]);
      daily = DailyRepository(db: db, settings: SettingsRepository(db));
    });

    tearDown(() => raw.close());

    test('a future day can be previewed without being written down', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));

      expect(daily.previewFor(tomorrow), hasLength(3));
      expect(db.readDailyAyahs(dayKey(tomorrow)), isNull,
          reason: 'scheduling looks ahead; history must not');
      expect(daily.history, isEmpty);
    });

    test('a stored day previews as stored, never as recomputed', () {
      final past = DateTime.now().subtract(const Duration(days: 2));
      db.writeDailyAyahs(dayKey(past), [11, 22, 33]);

      expect(daily.previewFor(past), [11, 22, 33]);
    });

    test('the window it builds spans the next seven days', () {
      final window = daily.upcomingReminders(from: DateTime(2026, 9, 6, 6));

      expect(window, hasLength(21));
      expect(window.map((r) => r.id).toSet(), hasLength(21));
    });

    test('a reminder reads as the ayah, translation first', () {
      db.writeAyahs([
        const Ayah(
          number: 5,
          surah: 1,
          numberInSurah: 5,
          juz: 1,
          page: 1,
          hizbQuarter: 1,
          ruku: 1,
          manzil: 1,
          sajda: false,
          sajdaObligatory: null,
          textAr: 'إِيَّاكَ نَعْبُدُ',
        ),
      ]);
      db.writeTranslations('en.sahih', {5: 'It is You we worship'});

      expect(daily.textFor(5, 'en.sahih'),
          (title: 'Al-Faatiha 1:5', body: 'It is You we worship'));

      // Arabic only: the body is the ayah itself rather than nothing.
      expect(daily.textFor(5, null)?.body, 'إِيَّاكَ نَعْبُدُ');
    });

    test('an ayah that has not synced yet has no reminder text', () {
      expect(daily.textFor(4000, 'en.sahih'), isNull);
    });
  });
}
