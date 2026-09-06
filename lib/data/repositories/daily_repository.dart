import 'dart:math';

import '../../domain/bismillah.dart';
import '../../domain/daily_seed.dart';
import '../../domain/models/ayah.dart';
import '../../domain/models/surah.dart';
import '../services/alquran_api_service.dart';
import '../services/local_store.dart';

/// The ayah of the day.
///
/// One ayah, held only for the day it belongs to. There is no yesterday and no
/// tomorrow here: the cache holds exactly one entry, and the moment its date is
/// not today it is thrown away and a new ayah is drawn.
class DailyRepository {
  const DailyRepository({
    required this.store,
    required this.api,
    this.total = ayahsInQuran,
  });

  /// 1 to 6236. Fixed by the text itself, not by anything the app downloads.
  /// Overridable only so a test can narrow the draw.
  static const ayahsInQuran = 6236;

  final LocalStore store;
  final AlquranApiService api;
  final int total;

  /// Today's ayah, fetched once and read from disk after that.
  ///
  /// [now] is injectable so a rollover can be tested without waiting a day.
  Future<DailyAyah> today({
    required String? translationEdition,
    DateTime? now,
  }) async {
    final key = dayKey(now ?? DateTime.now());

    final cached = _read(key, translationEdition);
    if (cached != null) return cached;

    // Yesterday's entry is dropped before the new one is fetched, so a failed
    // fetch cannot leave the wrong day's ayah on screen.
    store.clear();

    final number = Random().nextInt(total) + 1;
    final fetched = await api.dailyAyah(number, translationEdition);

    final daily = DailyAyah(
      // The API concatenates the Bismillah onto ayah 1, and a daily pick lands
      // there about once every fifty-five days.
      ayah: withoutOpeningBismillah(fetched.ayah),
      surah: fetched.surah,
      translation: fetched.translation,
    );

    store.write({
      'date': key,
      'edition': translationEdition,
      ...daily.toJson(),
    });
    return daily;
  }

  /// The cached ayah, or null when there is none, it belongs to another day, or
  /// it was fetched against a translation the user has since changed.
  DailyAyah? _read(String key, String? translationEdition) {
    final json = store.read();
    if (json['date'] != key) return null;
    if (json['edition'] != translationEdition) return null;
    return DailyAyah.fromJson(json);
  }
}

/// One ayah with the surah it came from — a bare ayah number cites nothing.
class DailyAyah {
  const DailyAyah({
    required this.ayah,
    required this.surah,
    this.translation,
  });

  /// Any opening Bismillah is already split off.
  final Ayah ayah;
  final Surah surah;
  final String? translation;

  Map<String, dynamic> toJson() => {
        'number': ayah.number,
        'numberInSurah': ayah.numberInSurah,
        'sajda': ayah.sajda,
        'sajdaObligatory': ayah.sajdaObligatory,
        'arabic': ayah.textAr,
        'translation': translation,
        'surahNumber': surah.number,
        'surahNameAr': surah.nameAr,
        'surahNameEn': surah.nameEn,
        'surahNameEnTranslation': surah.nameEnTranslation,
        'surahRevelationType': surah.revelationType,
        'surahAyahCount': surah.ayahCount,
      };

  static DailyAyah fromJson(Map<String, dynamic> json) => DailyAyah(
        ayah: Ayah(
          number: json['number'] as int,
          surah: json['surahNumber'] as int,
          numberInSurah: json['numberInSurah'] as int,
          // Only the fields the screen renders survive the round trip; juz,
          // page, hizb, ruku and manzil were never shown and are not stored.
          juz: 0,
          page: 0,
          hizbQuarter: 0,
          ruku: 0,
          manzil: 0,
          sajda: json['sajda'] as bool,
          sajdaObligatory: json['sajdaObligatory'] as bool?,
          textAr: json['arabic'] as String,
        ),
        surah: Surah(
          number: json['surahNumber'] as int,
          nameAr: json['surahNameAr'] as String,
          nameEn: json['surahNameEn'] as String,
          nameEnTranslation: json['surahNameEnTranslation'] as String,
          revelationType: json['surahRevelationType'] as String,
          ayahCount: json['surahAyahCount'] as int,
        ),
        translation: json['translation'] as String?,
      );
}
