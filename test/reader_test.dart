import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wasira/data/repositories/quran_repository.dart';
import 'package:wasira/data/repositories/settings_repository.dart';
import 'package:wasira/data/services/alquran_api_service.dart';
import 'package:wasira/data/services/database_service.dart';
import 'package:wasira/domain/bismillah.dart';
import 'package:wasira/ui/reader/reader_bloc.dart';
import 'package:wasira/ui/reader/reader_event.dart';
import 'package:wasira/ui/reader/reader_state.dart';
import 'package:wasira/ui/reader/widgets/ayah_tile.dart';

/// Asserts the reader's behaviour rather than its pixels: the goldens show what
/// it looks like, these say what must be true.
void main() {
  late Database db;
  late DatabaseService service;

  setUp(() {
    db = sqlite3.openInMemory();
    service = DatabaseService(db)..migrate();
  });
  tearDown(() => db.close());

  QuranRepository repoFor(int surah) => QuranRepository(
        db: service,
        api: AlquranApiService(
          client: MockClient((request) async {
            final path = request.url.path;
            final file = path.contains('uz.sodik')
                ? 'surah_${surah}_uz.json'
                : path.contains('/surah/$surah/')
                    ? 'surah_${surah}_ar.json'
                    : 'surah_list.json';
            return http.Response.bytes(
                File('test/fixtures/$file').readAsBytesSync(), 200);
          }),
        ),
      );

  Future<ReaderLoaded> load(int surah, {String? edition}) async {
    final bloc =
        ReaderBloc(
            repository: repoFor(surah),
            settings: SettingsRepository(service),
            translationEdition: edition)
          ..add(SurahRequested(surah));
    addTearDown(bloc.close);
    return await bloc.stream.firstWhere((s) => s is! ReaderLoading)
        as ReaderLoaded;
  }

  group('Bismillah reaches the reader correctly', () {
    test('Al-Baqarah gets a header and ayah 1 loses the prefix', () async {
      final state = await load(2, edition: 'uz.sodik');

      expect(state.bismillahHeader, bismillahUthmani);
      expect(state.ayahs.first.textAr, 'الٓمٓ');
      expect(state.ayahs.first.textAr, isNot(contains(bismillahUthmani)));
    });

    test('Al-Fatiha gets no header and keeps Bismillah as ayah 1', () async {
      final state = await load(1, edition: 'uz.sodik');

      expect(state.bismillahHeader, isNull);
      expect(state.ayahs.first.textAr, bismillahUthmani);
    });

    test('At-Tawbah gets no header and no Bismillah anywhere', () async {
      final state = await load(9, edition: 'uz.sodik');

      expect(state.bismillahHeader, isNull);
      for (final ayah in state.ayahs) {
        expect(ayah.textAr, isNot(contains(bismillahUthmani)));
      }
    });
  });

  group('sajda', () {
    test('32:15 is flagged, and flagged obligatory', () async {
      final state = await load(32, edition: 'uz.sodik');
      final sajda = state.ayahs.where((a) => a.sajda).toList();

      expect(sajda, hasLength(1));
      expect(sajda.single.numberInSurah, 15);
      expect(sajda.single.sajdaObligatory, isTrue);
    });

    test('ordinary ayahs carry no ruling', () async {
      final state = await load(2, edition: 'uz.sodik');

      expect(state.ayahs.every((a) => !a.sajda), isTrue);
      expect(state.ayahs.every((a) => a.sajdaObligatory == null), isTrue);
    });
  });

  group('translations', () {
    test('uz.sodik entries exceed the clamp threshold', () async {
      final state = await load(2, edition: 'uz.sodik');
      final first = state.translations[state.ayahs.first.number]!;

      expect(first.length, greaterThan(AyahTile.clampThreshold),
          reason: 'this is the case the Show more affordance exists for');
    });

    test('choosing no translation leaves the reader Arabic only', () async {
      final state = await load(2);

      expect(state.translations, isEmpty);
      expect(state.ayahs, isNotEmpty);
    });

    test('expanding one ayah does not expand the others', () async {
      final bloc = ReaderBloc(
          repository: repoFor(2),
          settings: SettingsRepository(service),
          translationEdition: 'uz.sodik')
        ..add(SurahRequested(2));
      addTearDown(bloc.close);
      final loaded =
          await bloc.stream.firstWhere((s) => s is! ReaderLoading) as ReaderLoaded;
      final target = loaded.ayahs.first.number;

      bloc.add(TranslationExpanded(target));
      final next = await bloc.stream.first as ReaderLoaded;

      expect(next.expanded, {target});
      expect(next.expanded.length, 1);
    });
  });

  group('Arabic font size', () {
    test('the reader opens at the stored size', () async {
      SettingsRepository(service).setArabicFontSize(22);

      final state = await load(2, edition: 'uz.sodik');

      expect(state.arabicSize, 22);
    });

    test('changing it updates the reader and persists for next launch',
        () async {
      final settings = SettingsRepository(service);
      final bloc = ReaderBloc(
        repository: repoFor(2),
        settings: settings,
        translationEdition: 'uz.sodik',
      )..add(SurahRequested(2));
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((s) => s is! ReaderLoading);

      bloc.add(ArabicSizeChanged(34));
      final next = await bloc.stream.first as ReaderLoaded;

      expect(next.arabicSize, 34);
      expect(settings.arabicFontSize, 34, reason: 'must outlive the bloc');
    });
  });
}
