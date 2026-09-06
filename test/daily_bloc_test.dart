import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wasira/data/repositories/daily_repository.dart';
import 'package:wasira/data/repositories/quran_repository.dart';
import 'package:wasira/data/repositories/settings_repository.dart';
import 'package:wasira/data/services/alquran_api_service.dart';
import 'package:wasira/data/services/database_service.dart';
import 'package:wasira/domain/bismillah.dart';
import 'package:wasira/domain/daily_seed.dart';
import 'package:wasira/domain/models/ayah.dart';
import 'package:wasira/domain/models/surah.dart';
import 'package:wasira/ui/daily/daily_bloc.dart';
import 'package:wasira/ui/daily/daily_event.dart';
import 'package:wasira/ui/daily/daily_state.dart';
import 'package:wasira/ui/daily/widgets/daily_screen.dart';
import 'package:wasira/l10n/app_localizations.dart';

void main() {
  late Database raw;
  late DatabaseService db;
  late DailyBloc bloc;

  List<Surah> realSurahs() => [
        for (final row in (jsonDecode(
                    File('test/fixtures/surah_list.json').readAsStringSync())
                as Map<String, dynamic>)['data'] as List)
          Surah.fromJson(row as Map<String, dynamic>),
      ];

  /// The whole Quran as placeholder text. Only the numbering has to be real
  /// here; the Arabic itself is the reader's test, not this one.
  void writeWholeQuran() {
    var number = 1;
    final ayahs = <Ayah>[];
    for (final surah in realSurahs()) {
      for (var n = 1; n <= surah.ayahCount; n++) {
        ayahs.add(Ayah(
          number: number++,
          surah: surah.number,
          numberInSurah: n,
          juz: 1,
          page: 1,
          hizbQuarter: 1,
          ruku: 1,
          manzil: 1,
          sajda: false,
          sajdaObligatory: null,
          textAr: 'ayah $number',
        ));
      }
    }
    db.writeAyahs(ayahs);
  }

  DailyBloc build({String? edition}) => DailyBloc(
        repository: QuranRepository(db: db, api: AlquranApiService()),
        daily: DailyRepository(db: db, settings: SettingsRepository(db)),
        settings: SettingsRepository(db),
        translationEdition: edition,
      );

  Stream<DailyState> states(DailyBloc bloc) => bloc.stream;

  setUp(() {
    raw = sqlite3.openInMemory();
    db = DatabaseService(raw)..migrate();
    db.writeSurahs(realSurahs());
    writeWholeQuran();
    bloc = build();
  });

  tearDown(() async {
    await bloc.close();
    raw.close();
  });

  test('today gives the configured number of ayahs, in Quran order', () async {
    bloc.add(DailyRequested());
    final state =
        await states(bloc).firstWhere((s) => s is DailyLoaded) as DailyLoaded;

    expect(state.ayahs, hasLength(SettingsRepository.defaultDailyCount));
    expect(
      state.ayahs.map((a) => a.ayah.number).toList(),
      orderedEquals([...state.ayahs.map((a) => a.ayah.number)]..sort()),
    );
    // A scattered pick is meaningless without the surah it came from.
    expect(state.ayahs.every((a) => a.surah.number == a.ayah.surah), isTrue);
  });

  test('the same day asked for twice gives the same ayahs', () async {
    bloc.add(DailyRequested());
    final first =
        await states(bloc).firstWhere((s) => s is DailyLoaded) as DailyLoaded;

    final second = build();
    addTearDown(second.close);
    second.add(DailyRequested());
    final again =
        await states(second).firstWhere((s) => s is DailyLoaded) as DailyLoaded;

    expect(again.ayahs.map((a) => a.ayah.number),
        first.ayahs.map((a) => a.ayah.number));
  });

  test('a past day loads and is stored', () async {
    final past = DateTime.now().subtract(const Duration(days: 5));
    bloc.add(DaySelected(past));
    final state =
        await states(bloc).firstWhere((s) => s is DailyLoaded) as DailyLoaded;

    expect(state.date, past);
    expect(db.readDailyAyahs(dayKey(past)), isNotNull);
  });

  test('a future day fails rather than inventing one', () async {
    bloc.add(DaySelected(DateTime.now().add(const Duration(days: 1))));
    final state = await states(bloc).firstWhere((s) => s is DailyFailed);

    expect(state, isA<DailyFailed>());
    expect(db.readDailyDates(), isEmpty);
  });

  test('waits for the sync rather than showing a half-empty day', () async {
    // A fresh database with surah headers but no ayah rows: exactly the window
    // between the surah list painting and the 6236-row sync finishing.
    final empty = sqlite3.openInMemory();
    final emptyDb = DatabaseService(empty)..migrate();
    emptyDb.writeSurahs(realSurahs());
    addTearDown(empty.close);

    final waiting = DailyBloc(
      repository: QuranRepository(db: emptyDb, api: AlquranApiService()),
      daily: DailyRepository(db: emptyDb, settings: SettingsRepository(emptyDb)),
      settings: SettingsRepository(emptyDb),
      translationEdition: null,
    );
    addTearDown(waiting.close);

    waiting.add(DailyRequested());
    final state = await waiting.stream.firstWhere((s) => s is! DailyLoading);

    expect(state, isA<DailyWaitingForSync>());
  });

  test('the count applies to the next day, not one already read', () async {
    final earlier = DateTime.now().subtract(const Duration(days: 3));
    final later = DateTime.now().subtract(const Duration(days: 2));

    bloc.add(DaySelected(earlier));
    final before =
        await states(bloc).firstWhere((s) => s is DailyLoaded) as DailyLoaded;
    expect(before.ayahs, hasLength(3));

    bloc.add(DailyCountChanged(5));
    final after = await states(bloc)
        .firstWhere((s) => s is DailyLoaded && s.count == 5) as DailyLoaded;

    // Still on the same day, and that day keeps what it was read with.
    expect(after.date, earlier);
    expect(after.ayahs, hasLength(3));

    bloc.add(DaySelected(later));
    final next =
        await states(bloc).firstWhere((s) => s is DailyLoaded) as DailyLoaded;
    expect(next.ayahs, hasLength(5));
  });

  test('there is one reminder time per ayah, spread across the day', () async {
    bloc.add(DailyRequested());
    final state =
        await states(bloc).firstWhere((s) => s is DailyLoaded) as DailyLoaded;

    expect(state.reminderTimes, hasLength(state.count));
    expect(state.reminderTimes, orderedEquals([8 * 60, 14 * 60, 20 * 60]));
  });

  test('moving a reminder keeps it and leaves the others alone', () async {
    bloc.add(DailyRequested());
    await states(bloc).firstWhere((s) => s is DailyLoaded);

    bloc.add(ReminderTimeChanged(1, 6 * 60 + 30));
    final state = await states(bloc).firstWhere(
        (s) => s is DailyLoaded && s.reminderTimes[1] == 390) as DailyLoaded;

    expect(state.reminderTimes, [8 * 60, 390, 20 * 60]);
    expect(SettingsRepository(db).reminderTimes, [8 * 60, 390, 20 * 60]);
  });

  test('raising the count adds reminder times rather than dropping them',
      () async {
    SettingsRepository(db).setReminderTimes([7 * 60, 12 * 60, 19 * 60]);
    SettingsRepository(db).setDailyCount(5);

    expect(SettingsRepository(db).reminderTimes.take(3),
        [7 * 60, 12 * 60, 19 * 60]);
    expect(SettingsRepository(db).reminderTimes, hasLength(5));
  });

  test('the calendar starts the day the app did', () async {
    bloc.add(DailyRequested());
    final state =
        await states(bloc).firstWhere((s) => s is DailyLoaded) as DailyLoaded;

    expect(dayKey(state.since), dayKey(DateTime.now()));
  });

  test('an ayah 1 arrives without the Bismillah glued to it', () async {
    // A daily pick can land on ayah 1, where the API concatenates the
    // Bismillah. 2:1 is the canonical case: the ayah is الٓمٓ alone.
    const glued = '$bismillahUthmani الٓمٓ';
    db.writeAyahs([
      const Ayah(
        number: 8,
        surah: 2,
        numberInSurah: 1,
        juz: 1,
        page: 2,
        hizbQuarter: 1,
        ruku: 1,
        manzil: 1,
        sajda: false,
        sajdaObligatory: null,
        textAr: glued,
      ),
    ]);
    final day = DateTime.now().subtract(const Duration(days: 9));
    db.writeDailyAyahs(dayKey(day), [8]);

    bloc.add(DaySelected(day));
    final state =
        await states(bloc).firstWhere((s) => s is DailyLoaded) as DailyLoaded;

    expect(state.ayahs.single.ayah.textAr, 'الٓمٓ');
  });

  testWidgets('the screen shows the day and its ayahs', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    // Built here, not in setUp: a bloc created outside the test body schedules
    // its microtasks in a zone this test's clock never runs.
    final screen = build();
    addTearDown(screen.close);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider.value(
          value: screen..add(DailyRequested()),
          child: const DailyScreen(),
        ),
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(find.text('Today'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsOneWidget);

    final state = screen.state as DailyLoaded;
    expect(state.ayahs, hasLength(3));
    for (final daily in state.ayahs) {
      expect(
        find.text('${daily.surah.nameEn} \u00b7 ${daily.ayah.numberInSurah}'),
        findsOneWidget,
      );
    }
  });
}
