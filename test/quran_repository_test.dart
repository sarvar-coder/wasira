import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wasira/data/repositories/quran_repository.dart';
import 'package:wasira/data/services/alquran_api_service.dart';
import 'package:wasira/data/services/database_service.dart';
import 'package:wasira/domain/models/edition.dart';
import 'package:wasira/domain/models/surah.dart';

Map<String, dynamic> _ayahJson(int n, int inSurah, String text) => {
      'number': n,
      'text': text,
      'numberInSurah': inSurah,
      'juz': 1,
      'manzil': 1,
      'page': 1,
      'ruku': 1,
      'hizbQuarter': 1,
      'sajda': false,
    };

http.Response _surahResponse(int number, List<Map<String, dynamic>> ayahs) =>
    http.Response.bytes(
      utf8.encode(jsonEncode({
        'code': 200,
        'status': 'OK',
        'data': {
          'number': number,
          'name': 'ٱلْفَاتِحَة',
          'englishName': 'Al-Faatiha',
          'englishNameTranslation': 'The Opening',
          'revelationType': 'Meccan',
          'numberOfAyahs': ayahs.length,
          'ayahs': ayahs,
        }
      })),
      200,
    );

void main() {
  late Database db;
  late DatabaseService service;
  var apiCalls = 0;

  setUp(() {
    apiCalls = 0;
    db = sqlite3.openInMemory();
    service = DatabaseService(db)..migrate();
  });
  tearDown(() => db.close());

  QuranRepository repo(http.Response Function() respond) => QuranRepository(
        db: service,
        api: AlquranApiService(client: MockClient((_) async {
          apiCalls++;
          return respond();
        })),
      );

  const alFatiha = Surah(
    number: 1,
    nameAr: 'ٱلْفَاتِحَة',
    nameEn: 'Al-Faatiha',
    nameEnTranslation: 'The Opening',
    revelationType: 'Meccan',
    ayahCount: 7,
  );

  test('surahs come from the database without touching the network', () async {
    service.writeSurahs([alFatiha]);

    final result = await repo(() => throw StateError('must not fetch')).surahs();

    expect(result.single.nameEn, 'Al-Faatiha');
    expect(apiCalls, 0);
  });

  test('ayahs fall back to the network when sync has not reached them',
      () async {
    final r = repo(() => _surahResponse(1, [_ayahJson(1, 1, 'بِسْمِ')]));

    final ayahs = await r.ayahs(1);

    expect(apiCalls, 1);
    expect(ayahs.single.textAr, 'بِسْمِ');
  });

  test('a fallback fetch is cached, so the second read is local', () async {
    final r = repo(() => _surahResponse(1, [_ayahJson(1, 1, 'بِسْمِ')]));

    await r.ayahs(1);
    await r.ayahs(1);

    expect(apiCalls, 1, reason: 'second read should come from the database');
  });

  test('translations are keyed by global ayah number', () async {
    final r = repo(() => _surahResponse(
        1, [_ayahJson(1, 1, 'In the name'), _ayahJson(2, 2, 'All praise')]));

    final texts = await r.translations(1, 'en.sahih');

    expect(texts, {1: 'In the name', 2: 'All praise'});
  });

  test('no translation edition means no network call and no rows', () async {
    final texts =
        await repo(() => throw StateError('must not fetch')).translations(1, null);

    expect(texts, isEmpty);
    expect(apiCalls, 0);
  });

  test('isSynced reports false until the Arabic edition is marked downloaded',
      () async {
    final r = repo(() => throw StateError('must not fetch'));
    expect(r.isSynced, isFalse);

    service.writeEdition(
      const Edition(
        identifier: QuranRepository.arabicEdition,
        language: 'ar',
        name: 'القرآن',
        englishName: 'Uthmani',
        format: 'text',
        type: 'quran',
        direction: 'rtl',
      ),
      downloaded: true,
    );

    expect(r.isSynced, isTrue);
  });
}
