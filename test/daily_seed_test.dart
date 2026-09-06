import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wasira/data/repositories/daily_repository.dart';
import 'package:wasira/data/repositories/settings_repository.dart';
import 'package:wasira/data/services/database_service.dart';
import 'package:wasira/domain/daily_seed.dart';

void main() {
  group('the day key', () {
    test('pads so days sort as text', () {
      expect(dayKey(DateTime(2026, 9, 6)), '2026-09-06');
      expect(dayKey(DateTime(2026, 12, 31)), '2026-12-31');
      expect(dayKey(DateTime(2026, 1, 1)).compareTo(dayKey(DateTime(2026, 9, 6))),
          lessThan(0));
    });

    test('is the local day, not the UTC one', () {
      // Late evening local time is still today. Converting to UTC first would
      // hand half the world tomorrow's ayahs before midnight.
      expect(dayKey(DateTime(2026, 9, 6, 23, 30)), '2026-09-06');
      expect(dayKey(DateTime(2026, 9, 6, 0, 15)), '2026-09-06');
    });
  });

  group('the pick', () {
    test('is the same for a (seed, date) pair, a thousand times over', () {
      final first = dailyAyahs(seed: 12345, date: DateTime(2026, 9, 6), count: 3);
      for (var i = 0; i < 1000; i++) {
        expect(dailyAyahs(seed: 12345, date: DateTime(2026, 9, 6), count: 3),
            first);
      }
    });

    test('differs from day to day', () {
      final days = {
        for (var d = 1; d <= 60; d++)
          dailyAyahs(seed: 12345, date: DateTime(2026, 9, 6).add(Duration(days: d)), count: 3)
              .join(','),
      };
      // A handful of collisions across 60 days would still be chance; a seed
      // that ignored the date would collapse them all into one.
      expect(days.length, greaterThan(55));
    });

    test('differs from seed to seed on the same day', () {
      final date = DateTime(2026, 9, 6);
      final seeds = {
        for (var s = 0; s < 60; s++)
          dailyAyahs(seed: s, date: date, count: 3).join(','),
      };
      expect(seeds.length, greaterThan(55));
    });

    test('returns exactly count ayahs, all distinct', () {
      for (final count in [1, 3, 5]) {
        final picked =
            dailyAyahs(seed: 99, date: DateTime(2026, 9, 6), count: count);
        expect(picked, hasLength(count));
        expect(picked.toSet(), hasLength(count));
      }
    });

    test('stays inside the Quran', () {
      for (var d = 0; d < 400; d++) {
        for (final n in dailyAyahs(
            seed: 7, date: DateTime(2026, 1, 1).add(Duration(days: d)), count: 5)) {
          expect(n, inInclusiveRange(1, 6236));
        }
      }
    });

    test('reads in the order of the Quran', () {
      final picked = dailyAyahs(seed: 42, date: DateTime(2026, 9, 6), count: 5);
      expect(picked, orderedEquals([...picked]..sort()));
    });

    test('asking for more ayahs than exist terminates', () {
      // A guard rather than a feature: without the clamp the draw loop would
      // never fill the set and would hang.
      expect(dailyAyahs(seed: 1, date: DateTime(2026, 9, 6), count: 9, total: 5),
          hasLength(5));
    });
  });

  group('storing a day', () {
    late Database raw;
    late DatabaseService db;
    late DailyRepository daily;

    setUp(() {
      raw = sqlite3.openInMemory();
      db = DatabaseService(raw)..migrate();
      daily = DailyRepository(db: db, settings: SettingsRepository(db));
    });

    tearDown(() => raw.close());

    test('generates on first ask and reads back the same afterwards', () {
      final date = DateTime(2026, 9, 6);
      final first = daily.ayahsFor(date);

      expect(first, hasLength(SettingsRepository.defaultDailyCount));
      expect(daily.ayahsFor(date), first);
      expect(db.readDailyAyahs('2026-09-06'), first);
    });

    test('a stored day survives the count changing', () {
      // Relative to now, so the pair stays in the past whenever this runs.
      final earlier = DateTime.now().subtract(const Duration(days: 3));
      final later = DateTime.now().subtract(const Duration(days: 2));
      final before = daily.ayahsFor(earlier);

      SettingsRepository(db).setDailyCount(5);

      // History is what was read, not what the settings now say.
      expect(daily.ayahsFor(earlier), before);
      expect(daily.ayahsFor(later), hasLength(5));
    });

    test('refuses a day that has not arrived', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(() => daily.ayahsFor(tomorrow), throwsArgumentError);
      expect(daily.history, isEmpty, reason: 'and stores nothing for it');
    });

    test('today is not the future, however late in the day it is', () {
      expect(() => daily.today, returnsNormally);
      expect(DailyRepository.isFuture(DateTime.now()), isFalse);
    });

    test('a missed day regenerates rather than staying blank', () {
      final missed = DateTime.now().subtract(const Duration(days: 30));
      expect(daily.ayahsFor(missed), hasLength(3));
      expect(daily.history, contains(dayKey(missed)));
    });

    test('history is newest first', () {
      daily.ayahsFor(DateTime(2026, 9, 4));
      daily.ayahsFor(DateTime(2026, 9, 6));
      daily.ayahsFor(DateTime(2026, 9, 5));

      expect(daily.history, ['2026-09-06', '2026-09-05', '2026-09-04']);
    });
  });

  group('the seed', () {
    late Database raw;
    late SettingsRepository settings;

    setUp(() {
      raw = sqlite3.openInMemory();
      settings = SettingsRepository(DatabaseService(raw)..migrate());
    });

    tearDown(() => raw.close());

    test('is generated once and then never moves', () {
      final seed = settings.dailySeed;
      for (var i = 0; i < 100; i++) {
        expect(settings.dailySeed, seed);
      }
    });

    test('survives a reopen of the repository', () {
      final seed = settings.dailySeed;
      expect(SettingsRepository(DatabaseService(raw)).dailySeed, seed);
    });

    test('the count falls back rather than accepting anything', () {
      expect(settings.dailyCount, SettingsRepository.defaultDailyCount);
      settings.setDailyCount(4);
      expect(settings.dailyCount, SettingsRepository.defaultDailyCount);
      settings.setDailyCount(5);
      expect(settings.dailyCount, 5);
    });
  });
}
