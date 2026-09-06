import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wasira/data/repositories/bookmark_repository.dart';
import 'package:wasira/data/repositories/quran_repository.dart';
import 'package:wasira/data/repositories/settings_repository.dart';
import 'package:wasira/data/services/alquran_api_service.dart';
import 'package:wasira/data/services/database_service.dart';
import 'package:wasira/domain/bismillah.dart';
import 'package:wasira/domain/models/ayah.dart';
import 'package:wasira/domain/models/surah.dart';
import 'package:wasira/l10n/app_localizations.dart';
import 'package:wasira/ui/bookmarks/bookmarks_bloc.dart';
import 'package:wasira/ui/bookmarks/bookmarks_event.dart';
import 'package:wasira/ui/bookmarks/bookmarks_state.dart';
import 'package:wasira/ui/bookmarks/widgets/bookmarks_screen.dart';

void main() {
  late Database raw;
  late DatabaseService db;
  late BookmarkRepository bookmarks;

  List<Surah> realSurahs() => [
        for (final row in (jsonDecode(
                    File('test/fixtures/surah_list.json').readAsStringSync())
                as Map<String, dynamic>)['data'] as List)
          Surah.fromJson(row as Map<String, dynamic>),
      ];

  Ayah ayah(int number, int surah, int inSurah, String text) => Ayah(
        number: number,
        surah: surah,
        numberInSurah: inSurah,
        juz: 1,
        page: 1,
        hizbQuarter: 1,
        ruku: 1,
        manzil: 1,
        sajda: false,
        sajdaObligatory: null,
        textAr: text,
      );

  BookmarksBloc build({String? edition}) => BookmarksBloc(
        repository: QuranRepository(db: db, api: AlquranApiService()),
        bookmarks: bookmarks,
        translationEdition: edition,
      );

  Future<BookmarksLoaded> loaded(BookmarksBloc bloc) async =>
      await bloc.stream.firstWhere((s) => s is BookmarksLoaded)
          as BookmarksLoaded;

  setUp(() {
    raw = sqlite3.openInMemory();
    db = DatabaseService(raw)..migrate();
    db.writeSurahs(realSurahs());
    db.writeAyahs([
      ayah(1, 1, 1, 'الحمد'),
      // 2:1, exactly as the API sends it: Bismillah glued onto ayah 1.
      ayah(8, 2, 1, '$bismillahUthmani الٓمٓ'),
      ayah(262, 2, 255, 'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ'),
      ayah(6236, 114, 6, 'مِنَ ٱلْجِنَّةِ وَٱلنَّاسِ'),
    ]);
    bookmarks = BookmarkRepository(db);
  });

  tearDown(() => raw.close());

  test('nothing saved is an empty list, not a failure', () async {
    final bloc = build()..add(BookmarksRequested());
    addTearDown(bloc.close);

    expect((await loaded(bloc)).entries, isEmpty);
  });

  test('saved ayahs come back in Quran order, whatever order they were saved',
      () async {
    for (final n in [6236, 262, 1]) {
      bookmarks.toggle(n);
    }

    final bloc = build()..add(BookmarksRequested());
    addTearDown(bloc.close);
    final state = await loaded(bloc);

    expect(state.entries.map((e) => e.ayah.number), [1, 262, 6236]);
    // Each carries the surah it came from: a bare ayah number cites nothing.
    expect(state.entries.map((e) => e.surah.nameEn),
        ['Al-Faatiha', 'Al-Baqara', 'An-Naas']);
    expect(state.entries[1].ayah.numberInSurah, 255);
  });

  test('a bookmarked ayah 1 loses the Bismillah glued to it', () async {
    bookmarks.toggle(8);

    final bloc = build()..add(BookmarksRequested());
    addTearDown(bloc.close);

    expect((await loaded(bloc)).entries.single.ayah.textAr, 'الٓمٓ');
  });

  test('removing one drops it and leaves the rest', () async {
    bookmarks.toggle(1);
    bookmarks.toggle(262);

    final bloc = build()..add(BookmarksRequested());
    addTearDown(bloc.close);
    await loaded(bloc);

    bloc.add(BookmarkRemoved(1));
    final after = await loaded(bloc);

    expect(after.entries.map((e) => e.ayah.number), [262]);
    expect(bookmarks.all, [262]);
  });

  test('carries the translation when one is chosen', () async {
    db.writeTranslations('en.sahih', {262: 'Allah - there is no deity'});
    bookmarks.toggle(262);

    final bloc = build(edition: 'en.sahih')..add(BookmarksRequested());
    addTearDown(bloc.close);

    expect((await loaded(bloc)).entries.single.translation,
        'Allah - there is no deity');
  });

  test('reading Arabic only carries no translation', () async {
    db.writeTranslations('en.sahih', {262: 'Allah - there is no deity'});
    bookmarks.toggle(262);

    final bloc = build()..add(BookmarksRequested());
    addTearDown(bloc.close);

    expect((await loaded(bloc)).entries.single.translation, isNull);
  });

  test('an ayah saved before the sync reached it is skipped, not crashed on',
      () async {
    // The table takes any ayah number; the row for it may not exist yet.
    bookmarks.toggle(4000);
    bookmarks.toggle(262);

    final bloc = build()..add(BookmarksRequested());
    addTearDown(bloc.close);

    expect((await loaded(bloc)).entries.map((e) => e.ayah.number), [262]);
  });

  testWidgets('the empty list says so rather than showing nothing',
      (tester) async {
    final bloc = build();
    addTearDown(bloc.close);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider.value(
          value: bloc..add(BookmarksRequested()),
          child: BookmarksScreen(
            repository: QuranRepository(db: db, api: AlquranApiService()),
            settings: SettingsRepository(db),
            bookmarks: bookmarks,
            translationEdition: null,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('No bookmarks yet'), findsOneWidget);
  });

  testWidgets('a saved ayah shows its reference and text', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    bookmarks.toggle(262);
    final bloc = build();
    addTearDown(bloc.close);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider.value(
          value: bloc..add(BookmarksRequested()),
          child: BookmarksScreen(
            repository: QuranRepository(db: db, api: AlquranApiService()),
            settings: SettingsRepository(db),
            bookmarks: bookmarks,
            translationEdition: null,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Al-Baqara  ·  2:255'), findsOneWidget);
  });
}
