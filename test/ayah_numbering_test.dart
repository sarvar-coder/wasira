import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wasira/domain/ayah_numbering.dart';
import 'package:wasira/domain/models/surah.dart';

Surah _surah(int number, int ayahCount) => Surah(
      number: number,
      nameAr: '',
      nameEn: '',
      nameEnTranslation: '',
      revelationType: 'Meccan',
      ayahCount: ayahCount,
    );

void main() {
  // The real 114 surah headers, as the API returns them.
  final quran = [
    for (final row in (jsonDecode(
                File('test/fixtures/surah_list.json').readAsStringSync())
            as Map<String, dynamic>)['data'] as List)
      Surah.fromJson(row as Map<String, dynamic>),
  ];

  test('Al-Fatiha holds global ayahs 1 to 7', () {
    expect(ayahNumbersBySurah([_surah(1, 7)])[1], [1, 2, 3, 4, 5, 6, 7]);
  });

  test('Al-Baqarah starts at 8, the ayah after Al-Fatiha ends', () {
    final numbers = ayahNumbersBySurah(quran);
    expect(numbers[2]!.first, 8);
    expect(numbers[2], hasLength(286));
    expect(numbers[3]!.first, 294);
  });

  test('surahs out of order still number from the start of the Quran', () {
    // readSurahs orders by number, but nothing in the type says so.
    final shuffled = [_surah(3, 200), _surah(1, 7), _surah(2, 286)];
    expect(ayahNumbersBySurah(shuffled)[1]!.first, 1);
    expect(ayahNumbersBySurah(shuffled)[2]!.first, 8);
    expect(ayahNumbersBySurah(shuffled)[3]!.first, 294);
  });

  test('the whole Quran numbers 1 to 6236 with no gap and no overlap', () {
    final numbers = ayahNumbersBySurah(quran);
    final flat = [for (final surah in quran) ...numbers[surah.number]!];

    expect(flat, hasLength(6236));
    expect(flat.first, 1);
    expect(flat.last, 6236);
    expect(flat.toSet(), hasLength(6236),
        reason: 'a repeated number would download one ayah twice and skip another');
  });

  test('a surah is missing rather than empty when it is not in the list', () {
    expect(ayahNumbersBySurah([_surah(1, 7)])[2], isNull);
  });
}
