import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'app.dart';
import 'data/repositories/quran_repository.dart';
import 'data/services/alquran_api_service.dart';
import 'data/services/audio_download_service.dart';
import 'data/services/database_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // One database file, in the app's own support directory. The background sync
  // isolate opens its own connection to the same path.
  final dir = await getApplicationSupportDirectory();
  final db = DatabaseService(sqlite3.open('${dir.path}/wasira.db'))..migrate();

  runApp(WasiraApp(
    db: db,
    repository: QuranRepository(db: db, api: AlquranApiService()),
    downloads: AudioDownloadService(root: dir),
  ));
}
