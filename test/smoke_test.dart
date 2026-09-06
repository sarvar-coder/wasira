import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wasira/app.dart';
import 'package:wasira/data/repositories/quran_repository.dart';
import 'package:wasira/data/services/alquran_api_service.dart';
import 'package:wasira/data/services/audio_download_service.dart';
import 'package:wasira/data/services/database_service.dart';

void main() {
  testWidgets('app builds and shows the language picker first', (tester) async {
    final db = sqlite3.openInMemory();
    final service = DatabaseService(db)..migrate();

    await tester.pumpWidget(WasiraApp(
      db: service,
      repository: QuranRepository(db: service, api: AlquranApiService()),
      downloads: AudioDownloadService(root: Directory.systemTemp),
    ));
    await tester.pump();

    expect(find.byType(WasiraApp), findsOneWidget);
    db.close();
  });
}
