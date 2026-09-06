import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wasira/data/services/alquran_api_service.dart';
import 'package:wasira/domain/models/ayah.dart';

/// Response shapes here mirror the live API, including the two quirks that
/// break naive parsing: `sajda` is `false` or an object, and Arabic text must
/// survive as UTF-8.
http.Response _ok(Object body) => http.Response.bytes(
    utf8.encode(jsonEncode({'code': 200, 'status': 'OK', 'data': body})), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _ayah(int n, int inSurah, {Object sajda = false}) => {
      'number': n,
      'text': 'ٱلْحَمْدُ لِلَّهِ',
      'numberInSurah': inSurah,
      'juz': 1,
      'manzil': 1,
      'page': 1,
      'ruku': 1,
      'hizbQuarter': 1,
      'sajda': sajda,
    };

Map<String, dynamic> _surah(int number, List<Map<String, dynamic>> ayahs) => {
      'number': number,
      'name': 'سُورَةُ ٱلْفَاتِحَةِ',
      'englishName': 'Al-Faatiha',
      'englishNameTranslation': 'The Opening',
      'revelationType': 'Meccan',
      'numberOfAyahs': ayahs.length,
      'ayahs': ayahs,
    };

AlquranApiService _service(http.Response Function(http.Request) handler) =>
    AlquranApiService(client: MockClient((r) async => handler(r)));

void main() {
  test('parses surahs and preserves Arabic through UTF-8', () async {
    // /quran/{edition} wraps the list in {surahs: [...], edition: {...}}
    final api = _service((_) => _ok({
          'surahs': [
            _surah(1, [_ayah(1, 1)])
          ]
        }));

    final result = await api.wholeEdition('quran-uthmani');

    expect(result.surahs.single.nameAr, 'سُورَةُ ٱلْفَاتِحَةِ');
    expect(result.ayahs.single.textAr, 'ٱلْحَمْدُ لِلَّهِ');
    expect(result.ayahs.single.surah, 1);
  });

  test('sajda false stays false, sajda object becomes true with its ruling',
      () async {
    final api = _service((_) => _ok({
          'surahs': [
            _surah(32, [
              _ayah(4197, 14),
              _ayah(4198, 15,
                  sajda: {'id': 10, 'recommended': false, 'obligatory': true}),
            ])
          ]
        }));

    final ayahs = (await api.wholeEdition('quran-uthmani')).ayahs;

    expect(ayahs[0].sajda, isFalse);
    expect(ayahs[0].sajdaObligatory, isNull);
    expect(ayahs[1].sajda, isTrue);
    expect(ayahs[1].sajdaObligatory, isTrue);
  });

  test('surah list reads ayah count from numberOfAyahs', () async {
    final api = _service((_) => _ok([
          {
            'number': 2,
            'name': 'ٱلْبَقَرَة',
            'englishName': 'Al-Baqara',
            'englishNameTranslation': 'The Cow',
            'revelationType': 'Medinan',
            'numberOfAyahs': 286,
          }
        ]));

    expect((await api.surahs()).single.ayahCount, 286);
  });

  test('editions carry direction, which drives translation text direction',
      () async {
    final api = _service((_) => _ok([
          {
            'identifier': 'ur.jalandhry',
            'language': 'ur',
            'name': 'اردو',
            'englishName': 'Jalandhry',
            'format': 'text',
            'type': 'translation',
            'direction': 'rtl',
          }
        ]));

    expect((await api.translationEditions()).single.direction, 'rtl');
  });

  test('non-200 status throws', () async {
    final api = _service((_) => http.Response('nope', 503));

    expect(() => api.surahs(), throwsA(isA<AlquranApiException>()));
  });

  test('200 status carrying a non-200 body code throws', () async {
    final api = _service((_) => http.Response.bytes(
        utf8.encode(jsonEncode({'code': 404, 'data': 'Invalid edition.'})), 200));

    expect(() => api.surahs(), throwsA(isA<AlquranApiException>()));
  });

  test('requests hit the documented paths', () async {
    final seen = <String>[];
    final api = _service((r) {
      seen.add(r.url.path);
      return _ok([]);
    });

    await api.surahs();
    await api.translationEditions();

    expect(seen, ['/v1/surah', '/v1/edition']);
  });

  group('against real captured API responses', () {
    http.Response fixture(String name) => http.Response.bytes(
        File('test/fixtures/$name').readAsBytesSync(), 200);

    test('real surah response parses, Bismillah still glued to ayah 1',
        () async {
      final api = _service((_) => fixture('surah_1_uthmani.json'));

      final result = await api.surah(1, 'quran-uthmani');

      expect(result.surahs.single.nameEn, 'Al-Faatiha');
      expect(result.ayahs, hasLength(7));
      // Surah 1 is the case where Bismillah legitimately IS ayah 1.
      expect(result.ayahs.first.textAr, contains('بِسْمِ'));
      expect(result.ayahs.first.surah, 1);
    });

    test('real sajda ayah carries the obligatory ruling', () async {
      final raw = jsonDecode(
          File('test/fixtures/ayah_32_15_sajda.json').readAsStringSync());
      final ayah = Ayah.fromJson(raw['data'] as Map<String, dynamic>, 32);

      expect(ayah.sajda, isTrue);
      expect(ayah.sajdaObligatory, isTrue);
    });

    test('real Urdu editions are marked rtl', () async {
      final api = _service((_) => fixture('editions_ur.json'));

      final editions = await api.translationEditions();

      expect(editions, isNotEmpty);
      expect(editions.every((e) => e.direction == 'rtl'), isTrue);
    });
  });
}
