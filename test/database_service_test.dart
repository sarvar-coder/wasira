import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wasira/data/services/database_service.dart';

void main() {
  late Database db;

  setUp(() => db = sqlite3.openInMemory());
  tearDown(() => db.close());

  Set<String> tables() => db
      .select("SELECT name FROM sqlite_master WHERE type='table'")
      .map((r) => r['name'] as String)
      .toSet();

  test('migrate creates every table and stamps the version', () {
    DatabaseService(db).migrate();

    expect(
      tables(),
      containsAll({
        'surahs', 'ayahs', 'editions', 'translations',
        'bookmarks', 'settings', 'daily_ayahs', 'audio_downloads',
      }),
    );
    expect(db.select('PRAGMA user_version').first.values.first,
        DatabaseService.schemaVersion);
  });

  test('migrate is idempotent', () {
    DatabaseService(db).migrate();
    final before = tables();

    DatabaseService(db).migrate(); // must not throw on an already-current db

    expect(tables(), before);
    expect(db.select('PRAGMA user_version').first.values.first,
        DatabaseService.schemaVersion);
  });

  test('sajda is stored per ayah so the reader can mark the 15', () {
    DatabaseService(db).migrate();
    db.execute('''
      INSERT INTO surahs VALUES (32, 'س', 'As-Sajda', 'The Prostration', 'Meccan', 30);
      INSERT INTO ayahs VALUES (4198, 32, 15, 21, 416, 168, 1, 5, 1, 'x');
    ''');

    final sajda = db.select('SELECT sajda FROM ayahs WHERE number = 4198');

    expect(sajda.first['sajda'], 1);
  });
}
