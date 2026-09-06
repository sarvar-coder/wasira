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

  test('sajda keeps the obligatory/recommended distinction', () {
    DatabaseService(db).migrate();
    db.execute('''
      INSERT INTO surahs VALUES (32, 'س', 'As-Sajda', 'The Prostration', 'Meccan', 30);
      INSERT INTO surahs VALUES (7, 'ا', 'Al-A''raaf', 'The Heights', 'Meccan', 206);
      -- 32:15 is obligatory, 7:206 is recommended
      INSERT INTO ayahs VALUES (4198, 32, 15, 21, 416, 168, 1, 5, 1, 1, 'x');
      INSERT INTO ayahs VALUES (1160, 7, 206, 9, 176, 71, 1, 2, 1, 0, 'y');
    ''');

    final rows = db.select(
        'SELECT number, sajda, sajda_obligatory FROM ayahs ORDER BY number');

    expect(rows.map((r) => r['sajda']), everyElement(1));
    expect(rows.firstWhere((r) => r['number'] == 4198)['sajda_obligatory'], 1);
    expect(rows.firstWhere((r) => r['number'] == 1160)['sajda_obligatory'], 0);
  });
}
