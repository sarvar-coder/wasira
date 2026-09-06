import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wasira/app.dart';
import 'package:wasira/data/services/alquran_api_service.dart';
import 'package:wasira/data/services/local_store.dart';

void main() {
  testWidgets('app builds and shows the translation picker first',
      (tester) async {
    final root = Directory.systemTemp.createTempSync('wasira_smoke');
    addTearDown(() => root.deleteSync(recursive: true));

    await tester.pumpWidget(WasiraApp(
      api: AlquranApiService(),
      settingsStore: LocalStore(File('${root.path}/settings.json')),
      dailyStore: LocalStore(File('${root.path}/daily.json')),
    ));
    await tester.pump();

    expect(find.byType(WasiraApp), findsOneWidget);
  });
}
