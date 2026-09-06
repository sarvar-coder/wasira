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

/// One row of `/ayah/{n}/editions/a,b`: an ayah with its surah and edition
/// inline, which is why nothing else has to be stored to render a citation.
Map<String, dynamic> _row(String edition, String text,
        {int inSurah = 255, Object sajda = false}) =>
    {
      ..._ayah(262, inSurah, sajda: sajda),
      'text': text,
      'surah': {
        'number': 2,
        'name': 'سُورَةُ البَقَرَةِ',
        'englishName': 'Al-Baqara',
        'englishNameTranslation': 'The Cow',
        'revelationType': 'Medinan',
        'numberOfAyahs': 286,
      },
      'edition': {'identifier': edition},
    };

AlquranApiService _service(http.Response Function(http.Request) handler) =>
    AlquranApiService(client: MockClient((r) async => handler(r)));

void main() {
  test('an ayah arrives with its surah, and the Arabic survives UTF-8',
      () async {
    final api = _service((_) => _ok([
          _row('quran-uthmani', 'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ'),
          _row('en.sahih', 'Allah - there is no deity except Him'),
        ]));

    final result = await api.dailyAyah(262, 'en.sahih');

    expect(result.ayah.textAr, 'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ');
    expect(result.translation, 'Allah - there is no deity except Him');
    expect(result.surah.nameEn, 'Al-Baqara');
    expect(result.surah.number, 2);
    expect(result.ayah.numberInSurah, 255);
  });

  test('reading Arabic only asks for one edition and carries no translation',
      () async {
    late String path;
    final api = _service((request) {
      path = request.url.path;
      return _ok([_row('quran-uthmani', 'ٱلْحَمْدُ لِلَّهِ')]);
    });

    final result = await api.dailyAyah(2, null);

    expect(path, '/v1/ayah/2/editions/quran-uthmani');
    expect(result.translation, isNull);
  });

  test('an ayah missing its Arabic throws rather than rendering blank',
      () async {
    final api = _service((_) => _ok([_row('en.sahih', 'only a translation')]));

    await expectLater(
        api.dailyAyah(262, 'en.sahih'), throwsA(isA<AlquranApiException>()));
  });

  test('sajda false stays false, sajda object becomes true with its ruling',
      () async {
    final plain = _service((_) => _ok([_row('quran-uthmani', 'نَصٌّ')]));
    final prostration = _service((_) => _ok([
          _row('quran-uthmani', 'نَصٌّ',
              sajda: {'id': 10, 'recommended': false, 'obligatory': true}),
        ]));

    expect((await plain.dailyAyah(262, null)).ayah.sajda, isFalse);
    expect((await plain.dailyAyah(262, null)).ayah.sajdaObligatory, isNull);

    final marked = (await prostration.dailyAyah(262, null)).ayah;
    expect(marked.sajda, isTrue);
    expect(marked.sajdaObligatory, isTrue);
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

    test('a real ayah 1 still arrives with the Bismillah glued on', () async {
      // Captured from the live API. Splitting it is DailyRepository's job; the
      // service must hand it over untouched.
      final ones = jsonDecode(
              File('test/fixtures/ayah_ones_uthmani.json').readAsStringSync())
          as Map<String, dynamic>;
      final api =
          _service((_) => _ok([_row('quran-uthmani', ones['2'] as String)]));

      final result = await api.dailyAyah(8, null);

      expect(result.ayah.textAr, startsWith('بِسْمِ'));
      expect(result.ayah.textAr, endsWith('الٓمٓ'));
    });

    test('a single unwrapped ayah response parses too', () async {
      // `/ayah/{n}/{edition}` answers with an object rather than a list; the
      // service handles both so the Arabic-only path cannot surprise.
      final api = _service((_) => fixture('ayah_32_15_sajda.json'));

      final result = await api.dailyAyah(3518, null);

      expect(result.ayah.sajda, isTrue);
      expect(result.ayah.sajdaObligatory, isTrue);
      expect(result.surah.number, 32);
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

  test('a hanging response times out instead of waiting forever', () async {
    final api = AlquranApiService(
      timeout: const Duration(milliseconds: 50),
      client: MockClient((_) => Future.delayed(
          const Duration(seconds: 5), () => http.Response('{}', 200))),
    );

    await expectLater(api.surahs(), throwsA(isA<AlquranApiException>()));
  });
}
