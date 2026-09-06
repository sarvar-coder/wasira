import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqlite3/sqlite3.dart';
import 'package:wasira/data/repositories/quran_repository.dart';
import 'package:wasira/data/repositories/settings_repository.dart';
import 'package:wasira/data/services/alquran_api_service.dart';
import 'package:wasira/data/services/audio_download_service.dart';
import 'package:wasira/data/services/database_service.dart';
import 'package:wasira/domain/models/surah.dart';
import 'package:wasira/domain/reciter.dart';
import 'package:wasira/ui/downloads/downloads_bloc.dart';
import 'package:wasira/ui/downloads/downloads_event.dart';
import 'package:wasira/ui/downloads/downloads_state.dart';
import 'package:wasira/ui/downloads/widgets/downloads_screen.dart';
import 'package:wasira/l10n/app_localizations.dart';

class _FakeCdn extends http.BaseClient {
  _FakeCdn({this.failOn = const {}});

  /// File names that 404, e.g. `9.mp3`.
  final Set<String> failOn;
  final requested = <Uri>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requested.add(request.url);
    if (failOn.contains(request.url.pathSegments.last)) {
      return http.StreamedResponse(const Stream.empty(), 404);
    }
    return http.StreamedResponse(Stream.value(const [1, 2, 3]), 200,
        contentLength: 3);
  }
}

void main() {
  late Database raw;
  late DatabaseService db;
  late Directory root;
  late _FakeCdn cdn;
  late AudioDownloadService downloads;
  late DownloadsBloc bloc;

  List<Surah> realSurahs() => [
        for (final row in (jsonDecode(
                    File('test/fixtures/surah_list.json').readAsStringSync())
                as Map<String, dynamic>)['data'] as List)
          Surah.fromJson(row as Map<String, dynamic>),
      ];

  DownloadsBloc build({_FakeCdn? client}) {
    cdn = client ?? _FakeCdn();
    downloads = AudioDownloadService(root: root, client: cdn);
    return DownloadsBloc(
      repository: QuranRepository(db: db, api: AlquranApiService()),
      downloads: downloads,
      settings: SettingsRepository(db),
    );
  }

  Stream<DownloadsLoaded> loaded(DownloadsBloc bloc) =>
      bloc.stream.where((s) => s is DownloadsLoaded).cast<DownloadsLoaded>();

  /// Waits until the row for [surah] settles, so assertions do not race the
  /// download's own events.
  Future<DownloadsLoaded> settled(DownloadsBloc bloc, int surah) => bloc.stream
      .firstWhere((s) =>
          s is DownloadsLoaded &&
          s.rowFor(surah) != null &&
          !s.rowFor(surah)!.downloading)
      .then((s) => s as DownloadsLoaded);

  setUp(() async {
    raw = sqlite3.openInMemory();
    db = DatabaseService(raw)..migrate();
    // Surahs come from the database, so nothing here touches the network.
    db.writeSurahs(realSurahs());
    root = Directory.systemTemp.createTempSync('wasira_downloads');
    bloc = build();
  });

  tearDown(() async {
    await bloc.close();
    root.deleteSync(recursive: true);
    raw.close();
  });

  test('lists all 114 surahs, none downloaded on a fresh install', () async {
    bloc.add(DownloadsRequested());
    final state = await loaded(bloc).first;

    expect(state.rows, hasLength(114));
    expect(state.bytes, 0);
    expect(state.rows.every((r) => r.done == 0), isTrue);
    // Al-Fatiha needs one file per ayah for a verse-by-verse reciter.
    expect(state.rows.first.total, 7);
    expect(state.rows.first.ayahNumbers, [1, 2, 3, 4, 5, 6, 7]);
  });

  test('opens on the reciter the reader is playing', () async {
    SettingsRepository(db).setReciter(Reciter.husaryMujawwad);
    final other = build();
    addTearDown(other.close);

    other.add(DownloadsRequested());
    final state = await loaded(other).first;

    expect(state.reciter, Reciter.husaryMujawwad);
  });

  test('downloading a surah reports its size and leaves it complete', () async {
    bloc.add(DownloadsRequested());
    await loaded(bloc).first;

    bloc.add(SurahDownloadRequested(1));
    final state = await settled(bloc, 1);
    final fatiha = state.rowFor(1)!;

    expect(fatiha.complete, isTrue);
    expect(fatiha.done, 7);
    expect(fatiha.bytes, 7 * 3);
    expect(fatiha.error, isNull);
    expect(state.bytes, 7 * 3);
  });

  test('al-Luhaidan needs one file for the whole surah', () async {
    // Chosen before the list loads, so the first scan is already his.
    bloc.add(DownloadsReciterChanged(Reciter.luhaidan));
    bloc.add(DownloadsRequested());
    await loaded(bloc).first;

    bloc.add(SurahDownloadRequested(2));
    final state = await settled(bloc, 2);

    expect(state.rowFor(2)!.total, 1);
    expect(state.rowFor(2)!.complete, isTrue);
    expect(cdn.requested.single.path,
        '/quran/audio-surah/128/ar.muhammadalluhaidan/2.mp3');
  });

  test('deleting reclaims the surah', () async {
    bloc.add(DownloadsRequested());
    await loaded(bloc).first;
    bloc.add(SurahDownloadRequested(1));
    await settled(bloc, 1);

    bloc.add(SurahDownloadDeleted(1));
    final state = await loaded(bloc)
        .firstWhere((s) => s.rowFor(1)!.bytes == 0);

    expect(state.rowFor(1)!.done, 0);
    expect(state.bytes, 0);
  });

  test('a failed download keeps what it fetched and says so', () async {
    final failing = build(client: _FakeCdn(failOn: {'4.mp3'}));
    addTearDown(failing.close);

    failing.add(DownloadsRequested());
    await loaded(failing).first;
    failing.add(SurahDownloadRequested(1));
    final state = await settled(failing, 1);
    final fatiha = state.rowFor(1)!;

    expect(fatiha.error, isNotNull);
    expect(fatiha.complete, isFalse);
    // Whatever landed before the failure is kept, so retrying resumes.
    expect(fatiha.partial, isTrue);
    expect(fatiha.bytes, fatiha.done * 3);
  });

  test('switching reciter shows that reciter disk, not the previous one',
      () async {
    bloc.add(DownloadsRequested());
    await loaded(bloc).first;
    bloc.add(SurahDownloadRequested(1));
    await settled(bloc, 1);

    bloc.add(DownloadsReciterChanged(Reciter.husaryMujawwad));
    final state = await loaded(bloc)
        .firstWhere((s) => s.reciter == Reciter.husaryMujawwad);

    expect(state.bytes, 0, reason: 'Alafasy files are not Husary files');
    expect(state.rowFor(1)!.done, 0);
  });

  test('the reader keeps its own reciter when this screen switches', () async {
    bloc.add(DownloadsRequested());
    await loaded(bloc).first;

    bloc.add(DownloadsReciterChanged(Reciter.luhaidan));
    await loaded(bloc)
        .firstWhere((s) => s.reciter == Reciter.luhaidan);

    // Managing disk is not choosing a voice.
    expect(SettingsRepository(db).reciter, Reciter.alafasy);
  });

  test('a surah already downloaded is not fetched again', () async {
    bloc.add(DownloadsRequested());
    await loaded(bloc).first;
    bloc.add(SurahDownloadRequested(1));
    await settled(bloc, 1);

    cdn.requested.clear();
    bloc.add(SurahDownloadRequested(1));
    await Future<void>.delayed(Duration.zero);

    expect(cdn.requested, isEmpty);
  });

  testWidgets('the screen renders the surah list and what it costs',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    // Built inside the test body on purpose: a bloc created in setUp schedules
    // its microtasks in the real zone, which a widget test's clock never runs,
    // so it would sit on DownloadsLoading forever.
    final screen = build();
    addTearDown(screen.close);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider.value(
          value: screen..add(DownloadsRequested()),
          child: const DownloadsScreen(),
        ),
      ),
    ));
    // Pumped rather than settled: the loading spinner animates forever, so
    // pumpAndSettle would never return. Downloading itself is asserted above,
    // against the bloc.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(find.text('Al-Faatiha'), findsOneWidget);
    expect(find.text(Reciter.alafasy.name), findsOneWidget);
    expect(find.text('0 KB on disk'), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsWidgets);
    // Nothing on disk, so nothing offers to be deleted.
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  test('sizes read the way a disk does', () {
    expect(formatBytes(0), '0 KB');
    expect(formatBytes(146830), '147 KB');
    // Al-Luhaidan's Al-Baqarah, measured against the live CDN.
    expect(formatBytes(55225948), '55.2 MB');
    expect(formatBytes(2400000000), '2.40 GB');
  });
}
