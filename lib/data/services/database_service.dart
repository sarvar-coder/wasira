import 'package:sqlite3/sqlite3.dart';

/// Owns the schema and its migrations. Takes an already-open [Database] so
/// tests can pass an in-memory one.
class DatabaseService {
  DatabaseService(this.db);

  final Database db;

  /// Bump this and add a case to [_migrate] for every schema change.
  static const schemaVersion = 1;

  void migrate() {
    var version = db.select('PRAGMA user_version').first.values.first! as int;
    while (version < schemaVersion) {
      _migrate(version + 1);
      version++;
      db.execute('PRAGMA user_version = $version');
    }
  }

  void _migrate(int to) {
    switch (to) {
      case 1:
        _createV1();
      default:
        throw StateError('no migration to schema version $to');
    }
  }

  void _createV1() => db.execute('''
    CREATE TABLE surahs (
      number               INTEGER PRIMARY KEY,
      name_ar              TEXT NOT NULL,
      name_en              TEXT NOT NULL,
      name_en_translation  TEXT NOT NULL,
      revelation_type      TEXT NOT NULL,
      ayah_count           INTEGER NOT NULL
    );

    CREATE TABLE ayahs (
      number          INTEGER PRIMARY KEY,
      surah           INTEGER NOT NULL REFERENCES surahs(number),
      number_in_surah INTEGER NOT NULL,
      juz             INTEGER NOT NULL,
      page            INTEGER NOT NULL,
      hizb_quarter    INTEGER NOT NULL,
      ruku            INTEGER NOT NULL,
      manzil          INTEGER NOT NULL,
      sajda           INTEGER NOT NULL,
      text_ar         TEXT NOT NULL
    );
    CREATE INDEX ayahs_by_surah ON ayahs(surah, number_in_surah);

    CREATE TABLE editions (
      identifier    TEXT PRIMARY KEY,
      language      TEXT NOT NULL,
      name          TEXT NOT NULL,
      english_name  TEXT NOT NULL,
      format        TEXT NOT NULL,
      type          TEXT NOT NULL,
      direction     TEXT,
      bitrate       INTEGER,
      downloaded_at INTEGER
    );

    CREATE TABLE translations (
      edition     TEXT NOT NULL REFERENCES editions(identifier),
      ayah_number INTEGER NOT NULL REFERENCES ayahs(number),
      text        TEXT NOT NULL,
      PRIMARY KEY (edition, ayah_number)
    );

    CREATE TABLE bookmarks (
      ayah_number INTEGER PRIMARY KEY REFERENCES ayahs(number),
      created_at  INTEGER NOT NULL,
      note        TEXT
    );

    CREATE TABLE settings (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );

    CREATE TABLE daily_ayahs (
      date         TEXT PRIMARY KEY,
      ayah_numbers TEXT NOT NULL
    );

    CREATE TABLE audio_downloads (
      edition TEXT NOT NULL REFERENCES editions(identifier),
      surah   INTEGER NOT NULL REFERENCES surahs(number),
      total   INTEGER NOT NULL,
      done    INTEGER NOT NULL,
      PRIMARY KEY (edition, surah)
    );
  ''');
}
