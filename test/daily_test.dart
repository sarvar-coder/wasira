import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wasira/data/repositories/daily_repository.dart';
import 'package:wasira/data/repositories/settings_repository.dart';
import 'package:wasira/data/services/alquran_api_service.dart';
import 'package:wasira/data/services/local_store.dart';
import 'package:wasira/domain/bismillah.dart';
import 'package:wasira/domain/daily_seed.dart';
import 'package:wasira/l10n/app_localizations.dart';
import 'package:wasira/ui/daily/daily_bloc.dart';
import 'package:wasira/ui/daily/daily_event.dart';
import 'package:wasira/ui/daily/daily_state.dart';
import 'package:wasira/ui/daily/widgets/daily_screen.dart';

void main() {
  late Directory root;
  late LocalStore dailyStore;
  late LocalStore settingsStore;
  late SettingsRepository settings;
  var requests = 0;

  /// The shape `/ayah/{n}/editions/a,b` really returns, taken from the live
  /// response: two rows, each carrying its surah inline.
  http.Client cdn(
          {String arabic = 'نَصٌّ', int numberInSurah = 255, bool fail = false}) =>
      MockClient((request) async {
        requests++;
        if (fail) return http.Response('', 503);
        return http.Response(
          jsonEncode({
            'code': 200,
            'status': 'OK',
            'data': [
              {
                'number': 262,
                'text': arabic,
                'numberInSurah': numberInSurah,
                'juz': 3, 'page': 42, 'hizbQuarter': 20,
                'ruku': 35, 'manzil': 1, 'sajda': false,
                'surah': {
                  'number': 2,
                  'name': 'سُورَةُ البَقَرَةِ',
                  'englishName': 'Al-Baqara',
                  'englishNameTranslation': 'The Cow',
                  'numberOfAyahs': 286,
                  'revelationType': 'Medinan',
                },
                'edition': {'identifier': 'quran-uthmani'},
              },
              {
                'number': 262,
                'text': 'Allah - there is no deity except Him',
                'numberInSurah': 255,
                'juz': 3, 'page': 42, 'hizbQuarter': 20,
                'ruku': 35, 'manzil': 1, 'sajda': false,
                'surah': {
                  'number': 2,
                  'name': 'سُورَةُ البَقَرَةِ',
                  'englishName': 'Al-Baqara',
                  'englishNameTranslation': 'The Cow',
                  'numberOfAyahs': 286,
                  'revelationType': 'Medinan',
                },
                'edition': {'identifier': 'en.sahih'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

  DailyRepository repo(
          {String arabic = 'نَصٌّ',
          int numberInSurah = 255,
          bool fail = false}) =>
      DailyRepository(
        store: dailyStore,
        api: AlquranApiService(
            client: cdn(
                arabic: arabic, numberInSurah: numberInSurah, fail: fail)),
      );

  setUp(() {
    root = Directory.systemTemp.createTempSync('wasira_daily');
    dailyStore = LocalStore(File('${root.path}/daily.json'));
    settingsStore = LocalStore(File('${root.path}/settings.json'));
    settings = SettingsRepository(settingsStore);
    requests = 0;
  });

  tearDown(() => root.deleteSync(recursive: true));

  group('the ayah of the day', () {
    test('is fetched once and read from disk after that', () async {
      final daily = repo();
      final first = await daily.today(translationEdition: 'en.sahih');

      expect(requests, 1);
      expect(first.surah.nameEn, 'Al-Baqara');
      expect(first.ayah.numberInSurah, 255);
      expect(first.translation, 'Allah - there is no deity except Him');

      final again = await daily.today(translationEdition: 'en.sahih');
      expect(requests, 1, reason: 'today is already on disk');
      expect(again.ayah.textAr, first.ayah.textAr);
    });

    test('is erased and drawn again when the day rolls over', () async {
      final daily = repo();
      await daily.today(translationEdition: 'en.sahih');
      expect(dailyStore.read()['date'], dayKey(DateTime.now()));

      await daily.today(
        translationEdition: 'en.sahih',
        now: DateTime.now().add(const Duration(days: 1)),
      );

      expect(requests, 2, reason: 'tomorrow is a different ayah');
      expect(dailyStore.read()['date'],
          dayKey(DateTime.now().add(const Duration(days: 1))));
    });

    test('holds exactly one day, never a history', () async {
      final daily = repo();
      for (var d = 0; d < 4; d++) {
        await daily.today(
          translationEdition: 'en.sahih',
          now: DateTime.now().add(Duration(days: d)),
        );
      }

      // One file, one entry. Nothing accumulates.
      expect(dailyStore.read()['date'],
          dayKey(DateTime.now().add(const Duration(days: 3))));
      expect(root.listSync().where((f) => f.path.endsWith('.json')),
          hasLength(1));
    });

    test('is refetched when the translation changes under it', () async {
      final daily = repo();
      await daily.today(translationEdition: 'en.sahih');
      await daily.today(translationEdition: 'uz.sodik');

      expect(requests, 2,
          reason: 'a cached ayah carries the translation it was fetched with');
    });

    test('loses the Bismillah glued onto ayah 1', () async {
      // 2:1 as the API sends it. A daily pick lands on an ayah 1 about once
      // every fifty-five days.
      final daily = repo(arabic: '$bismillahUthmani الٓمٓ', numberInSurah: 1);
      final today = await daily.today(translationEdition: 'en.sahih');

      expect(today.ayah.textAr, 'الٓمٓ');
    });

    test('draws inside the Quran', () async {
      for (var i = 0; i < 200; i++) {
        dailyStore.clear();
        await repo().today(translationEdition: 'en.sahih');
      }
      // The draw itself is what is under test; the fake always answers for 262.
      expect(requests, 200);
    });

    test('a failed fetch leaves nothing behind to show tomorrow', () async {
      await expectLater(
          repo(fail: true).today(translationEdition: 'en.sahih'),
          throwsA(isA<AlquranApiException>()));

      expect(dailyStore.read(), isEmpty);
    });
  });

  group('the screen', () {
    Future<DailyBloc> pump(WidgetTester tester, {bool fail = false}) async {
      settings.setTranslationEdition('en.sahih', 'Saheeh International');
      final bloc = DailyBloc(daily: repo(fail: fail), settings: settings);
      addTearDown(bloc.close);

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc..add(DailyRequested()),
            child: const DailyScreen(),
          ),
        ),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      return bloc;
    }

    testWidgets('shows the ayah, its reference and its translation',
        (tester) async {
      await pump(tester);

      expect(find.text('Al-Baqara  ·  2:255'), findsOneWidget);
      expect(find.text('Allah - there is no deity except Him'), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);
    });

    testWidgets('offers a retry rather than a blank window when offline',
        (tester) async {
      final bloc = await pump(tester, fail: true);

      expect(bloc.state, isA<DailyUnavailable>());
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('reminders', () {
    test('are five, spread across the waking day', () {
      expect(settings.reminderTimes,
          [8 * 60, 11 * 60, 14 * 60, 17 * 60, 20 * 60]);
      expect(settings.reminderTimes, hasLength(SettingsRepository.reminderCount));
    });

    test('moving one keeps it and leaves the others alone', () {
      final times = [...settings.reminderTimes]..[2] = 6 * 60 + 30;
      settings.setReminderTimes(times);

      expect(SettingsRepository(settingsStore).reminderTimes,
          [8 * 60, 11 * 60, 390, 17 * 60, 20 * 60]);
    });

    test('an out-of-range time is clamped rather than stored', () {
      settings.setReminderTimes([99999, 1, 2, 3, 4]);
      expect(SettingsRepository(settingsStore).reminderTimes.first, 1439);
    });

    test('never grow past five, however many are written', () {
      settings.setReminderTimes(List.filled(20, 600));
      expect(SettingsRepository(settingsStore).reminderTimes, hasLength(5));
    });
  });

  group('settings on disk', () {
    test('survive being reopened', () {
      settings.setArabicFontSize(22);
      settings.setTranslationEdition('uz.sodik');

      final reopened = SettingsRepository(settingsStore);
      expect(reopened.arabicFontSize, 22);
      expect(reopened.translationEdition, 'uz.sodik');
    });

    test('fall back rather than rendering at an arbitrary size', () {
      settings.setArabicFontSize(99);
      expect(settings.arabicFontSize, SettingsRepository.defaultArabicSize);
    });

    test('a corrupt file reads as a first launch, not a crash', () {
      settingsStore.file.writeAsStringSync('{ this is not json');

      expect(settings.translationEdition, isNull);
      expect(settings.arabicFontSize, SettingsRepository.defaultArabicSize);
    });
  });

  group('changing the translation', () {
    test('refetches, because the cached ayah carries the old one', () async {
      settings.setTranslationEdition('en.sahih', 'Saheeh International');
      final bloc = DailyBloc(daily: repo(), settings: settings);
      addTearDown(bloc.close);

      bloc.add(DailyRequested());
      await bloc.stream.firstWhere((s) => s is DailyLoaded);
      expect(requests, 1);

      bloc.add(TranslationEditionChanged('uz.sodik', 'Sodik'));
      final after = await bloc.stream.firstWhere(
          (s) => s is DailyLoaded && s.translationName == 'Sodik');

      expect(requests, 2);
      expect((after as DailyLoaded).translationName, 'Sodik');
      expect(SettingsRepository(settingsStore).translationEdition, 'uz.sodik');
    });

    test('survives a relaunch, name and all', () {
      settings.setTranslationEdition('uz.sodik', 'Muhammad Sodik');

      final reopened = SettingsRepository(settingsStore);
      expect(reopened.translationEdition, 'uz.sodik');
      expect(reopened.translationName, 'Muhammad Sodik');
    });

    test('an edition stored without a name falls back to the identifier', () {
      // Written by an older build, or by hand.
      settingsStore.write({'translation_edition': 'en.sahih'});

      expect(SettingsRepository(settingsStore).translationName, 'en.sahih');
    });
  });
}
