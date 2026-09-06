import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wasira/data/services/alquran_api_service.dart';
import 'package:wasira/data/services/database_service.dart';
import 'package:wasira/data/services/sync_service.dart';

Map<String, dynamic> _ayah(int n, int inSurah, String text) => {
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

http.Response _edition(List<Map<String, dynamic>> ayahs) => http.Response.bytes(
      utf8.encode(jsonEncode({
        'code': 200,
        'status': 'OK',
        'data': {
          'surahs': [
            {
              'number': 1,
              'name': 'ٱلْفَاتِحَة',
              'englishName': 'Al-Faatiha',
              'englishNameTranslation': 'The Opening',
              'revelationType': 'Meccan',
              'numberOfAyahs': ayahs.length,
              'ayahs': ayahs,
            }
          ]
        }
      })),
      200,
    );

void main() {
  late Database db;
  late DatabaseService service;

  setUp(() {
    db = sqlite3.openInMemory();
    service = DatabaseService(db)..migrate();
  });
  tearDown(() => db.close());

  AlquranApiService apiReturning(http.Response response) =>
      AlquranApiService(client: MockClient((_) async => response));

  int count(String table) =>
      db.select('SELECT COUNT(*) c FROM $table').first['c'] as int;

  test('arabic edition fills ayahs, not translations', () async {
    final progress = <double>[];

    await syncEditionInto(
      db: service,
      api: apiReturning(_edition([_ayah(1, 1, 'بِسْمِ ٱللَّهِ')])),
      editionId: 'quran-uthmani',
      isArabic: true,
      onProgress: progress.add,
    );

    expect(count('surahs'), 1);
    expect(count('ayahs'), 1);
    expect(count('translations'), 0);
    expect(db.select('SELECT text_ar FROM ayahs').first['text_ar'],
        'بِسْمِ ٱللَّهِ');
  });

  test('translation edition fills translations, not ayahs', () async {
    await syncEditionInto(
      db: service,
      api: apiReturning(_edition([_ayah(1, 1, 'In the name of Allah')])),
      editionId: 'en.sahih',
      isArabic: false,
      onProgress: (_) {},
    );

    expect(count('ayahs'), 0);
    expect(count('translations'), 1);
    expect(db.select('SELECT text FROM translations').first['text'],
        'In the name of Allah');
  });

  test('progress starts at 0, ends at 1, never goes backwards', () async {
    final progress = <double>[];

    await syncEditionInto(
      db: service,
      api: apiReturning(_edition([_ayah(1, 1, 'x')])),
      editionId: 'quran-uthmani',
      isArabic: true,
      onProgress: progress.add,
    );

    expect(progress.first, 0);
    expect(progress.last, 1);
    for (var i = 1; i < progress.length; i++) {
      expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
    }
  });

  test('re-syncing the same edition does not duplicate rows', () async {
    Future<void> sync() => syncEditionInto(
          db: service,
          api: apiReturning(_edition([_ayah(1, 1, 'x'), _ayah(2, 2, 'y')])),
          editionId: 'quran-uthmani',
          isArabic: true,
          onProgress: (_) {},
        );

    await sync();
    await sync();

    expect(count('ayahs'), 2);
    expect(count('surahs'), 1);
  });

  test('a failed fetch leaves the database untouched', () async {
    final api = AlquranApiService(
        client: MockClient((_) async => http.Response('boom', 500)));

    await expectLater(
      syncEditionInto(
        db: service,
        api: api,
        editionId: 'quran-uthmani',
        isArabic: true,
        onProgress: (_) {},
      ),
      throwsA(isA<AlquranApiException>()),
    );
    expect(count('surahs'), 0);
    expect(count('ayahs'), 0);
  });
}
