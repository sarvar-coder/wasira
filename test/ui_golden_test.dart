import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wasira/data/repositories/quran_repository.dart';
import 'package:wasira/data/services/alquran_api_service.dart';
import 'package:wasira/data/services/database_service.dart';
import 'package:wasira/ui/core/themes/tokens.dart';
import 'package:wasira/ui/onboarding/onboarding_bloc.dart';
import 'package:wasira/ui/onboarding/onboarding_event.dart';
import 'package:wasira/ui/onboarding/widgets/onboarding_screen.dart';
import 'package:wasira/ui/surah_list/surah_list_bloc.dart';
import 'package:wasira/ui/surah_list/surah_list_event.dart';
import 'package:wasira/ui/surah_list/widgets/surah_list_screen.dart';

/// Renders the real screens against real captured API responses, so the
/// goldens show what a user actually sees rather than a mock-shaped guess.
Future<void> _loadFont(String family, String path) async {
  final loader = FontLoader(family)
    ..addFont(rootBundle.load(path).then((d) => d.buffer.asByteData()));
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Without this every glyph renders as a box: the test environment has no
  // system fonts, so goldens would show layout but no readable text.
  setUpAll(() async {
    await _loadFont('Amiri', 'assets/fonts/Amiri-Regular.ttf');
    await _loadFont('AmiriQuran', 'assets/fonts/AmiriQuran-Regular.ttf');
  });

  late Database db;
  late DatabaseService service;

  setUp(() {
    db = sqlite3.openInMemory();
    service = DatabaseService(db)..migrate();
  });
  tearDown(() => db.close());

  QuranRepository repoServing(String fixture) => QuranRepository(
        db: service,
        api: AlquranApiService(
          client: MockClient((_) async => http.Response.bytes(
              File('test/fixtures/$fixture').readAsBytesSync(), 200)),
        ),
      );

  Future<void> render(WidgetTester tester, Widget child,
      {Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final tokens = brightness == Brightness.light ? Tokens.light : Tokens.dark;
    await tester.pumpWidget(MaterialApp(
      theme: tokens.theme.copyWith(
        textTheme: tokens.theme.textTheme.apply(fontFamily: 'Amiri'),
      ),
      home: child,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('language picker with all real translations', (tester) async {
    final bloc = OnboardingBloc(
        repository: repoServing('editions_all.json'), db: service)
      ..add(EditionsRequested());
    addTearDown(bloc.close);

    await render(
      tester,
      BlocProvider.value(
          value: bloc, child: const Scaffold(body: OnboardingScreen())),
    );

    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/onboarding_picker.png'));
  });

  testWidgets('surah list with all 114 real surahs', (tester) async {
    final bloc = SurahListBloc(repoServing('surah_list.json'))
      ..add(SurahListRequested());
    addTearDown(bloc.close);

    await render(
      tester,
      BlocProvider.value(
          value: bloc, child: const Scaffold(body: SurahListScreen())),
    );

    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/surah_list.png'));
  });

  testWidgets('surah list in dark mode', (tester) async {
    final bloc = SurahListBloc(repoServing('surah_list.json'))
      ..add(SurahListRequested());
    addTearDown(bloc.close);

    await render(
      tester,
      BlocProvider.value(
          value: bloc, child: const Scaffold(body: SurahListScreen())),
      brightness: Brightness.dark,
    );

    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/surah_list_dark.png'));
  });
}
