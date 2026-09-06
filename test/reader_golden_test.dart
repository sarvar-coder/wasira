import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wasira/data/repositories/quran_repository.dart';
import 'package:wasira/data/repositories/settings_repository.dart';
import 'package:wasira/data/services/alquran_api_service.dart';
import 'package:wasira/data/services/audio_download_service.dart';
import 'package:wasira/data/services/database_service.dart';
import 'package:wasira/l10n/app_localizations.dart';
import 'package:wasira/ui/core/themes/tokens.dart';
import 'package:wasira/ui/reader/widgets/reader_screen.dart';

/// Renders the reader against real captured text. Each surah here exists to
/// exercise one case that is easy to get wrong.
Future<void> _loadFont(String family, String path) async {
  final loader = FontLoader(family)
    ..addFont(rootBundle.load(path).then((d) => d.buffer.asByteData()));
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFont('AmiriQuran', 'assets/fonts/AmiriQuran-Regular.ttf');
    await _loadFont('Amiri', 'assets/fonts/Amiri-Regular.ttf');
  });

  late Database db;
  late DatabaseService service;

  setUp(() {
    db = sqlite3.openInMemory();
    service = DatabaseService(db)..migrate();
  });
  tearDown(() => db.close());

  /// Serves the Arabic or translation fixture depending on which edition the
  /// repository asks for.
  QuranRepository repoFor(int surah) => QuranRepository(
        db: service,
        api: AlquranApiService(
          client: MockClient((request) async {
            final path = request.url.path;
            final file = path.contains('uz.sodik')
                ? 'surah_${surah}_uz.json'
                : path.contains('/surah/')
                    ? 'surah_${surah}_ar.json'
                    : 'surah_list.json';
            return http.Response.bytes(
                File('test/fixtures/$file').readAsBytesSync(), 200);
          }),
        ),
      );

  Future<void> render(WidgetTester tester, int surah,
      {String? edition, double height = 1700}) async {
    tester.view.physicalSize = Size(1100, height);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepositoryProvider(
      // Nothing is downloaded here, so every source resolves to the CDN and
      // the goldens stay about text rather than audio.
      create: (_) => AudioDownloadService(root: Directory.systemTemp),
      child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: Tokens.light.theme.copyWith(
        textTheme: Tokens.light.theme.textTheme.apply(fontFamily: 'Amiri'),
      ),
      home: ReaderScreen(
        surah: surah,
        repository: repoFor(surah),
        settings: SettingsRepository(service),
        translationEdition: edition,
      ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Al-Baqarah: Bismillah is a header, ayah 1 is alif-lam-meem',
      (tester) async {
    await render(tester, 2, edition: 'uz.sodik');
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/reader_al_baqarah.png'));
  });

  testWidgets('Al-Fatiha: Bismillah IS ayah 1, so no header', (tester) async {
    await render(tester, 1, edition: 'uz.sodik');
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/reader_al_fatiha.png'));
  });

  testWidgets('At-Tawbah: no Bismillah anywhere', (tester) async {
    await render(tester, 9, edition: 'uz.sodik');
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/reader_at_tawbah.png'));
  });

  testWidgets('As-Sajda: 32:15 carries the prostration mark', (tester) async {
    await render(tester, 32, edition: 'uz.sodik', height: 3400);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/reader_as_sajda.png'));
  });

  testWidgets('Arabic only, no translation selected', (tester) async {
    await render(tester, 2);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/reader_arabic_only.png'));
  });
}
