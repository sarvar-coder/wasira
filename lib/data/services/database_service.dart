import 'package:sqlite3/sqlite3.dart';

import '../../domain/models/ayah.dart';
import '../../domain/models/edition.dart';
import '../../domain/models/surah.dart';

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
      sajda_obligatory INTEGER,
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

  /// Bulk writes run inside one transaction with a prepared statement. 6236
  /// individual inserts outside a transaction take seconds; inside one they
  /// take milliseconds.
  void writeSurahs(List<Surah> surahs) => _tx(() {
        final stmt = db.prepare(
            'INSERT OR REPLACE INTO surahs VALUES (?, ?, ?, ?, ?, ?)');
        try {
          for (final s in surahs) {
            stmt.execute([
              s.number, s.nameAr, s.nameEn,
              s.nameEnTranslation, s.revelationType, s.ayahCount,
            ]);
          }
        } finally {
          stmt.close();
        }
      });

  void writeAyahs(List<Ayah> ayahs) => _tx(() {
        final stmt = db.prepare(
            'INSERT OR REPLACE INTO ayahs VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
        try {
          for (final a in ayahs) {
            stmt.execute([
              a.number, a.surah, a.numberInSurah, a.juz, a.page,
              a.hizbQuarter, a.ruku, a.manzil,
              a.sajda ? 1 : 0,
              a.sajdaObligatory == null ? null : (a.sajdaObligatory! ? 1 : 0),
              a.textAr,
            ]);
          }
        } finally {
          stmt.close();
        }
      });

  /// [texts] maps global ayah number to that edition's translation.
  void writeTranslations(String edition, Map<int, String> texts) => _tx(() {
        final stmt = db.prepare(
            'INSERT OR REPLACE INTO translations VALUES (?, ?, ?)');
        try {
          texts.forEach((ayah, text) => stmt.execute([edition, ayah, text]));
        } finally {
          stmt.close();
        }
      });

  void writeEdition(Edition e, {bool downloaded = false}) => db.execute(
        'INSERT OR REPLACE INTO editions VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          e.identifier, e.language, e.name, e.englishName,
          e.format, e.type, e.direction, e.bitrate,
          downloaded ? DateTime.now().millisecondsSinceEpoch : null,
        ],
      );

  bool hasEdition(String identifier) => db.select(
        'SELECT downloaded_at FROM editions WHERE identifier = ?',
        [identifier],
      ).any((r) => r['downloaded_at'] != null);

  void _tx(void Function() body) {
    db.execute('BEGIN');
    try {
      body();
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  List<Surah> readSurahs() => db
      .select('SELECT * FROM surahs ORDER BY number')
      .map(_surahOf)
      .toList(growable: false);

  List<Ayah> readAyahs(int surah) => db
      .select('SELECT * FROM ayahs WHERE surah = ? ORDER BY number_in_surah',
          [surah])
      .map(_ayahOf)
      .toList(growable: false);

  /// Keyed by global ayah number, matching how the reader pairs them up.
  Map<int, String> readTranslations(int surah, String edition) => {
        for (final r in db.select(
          'SELECT t.ayah_number n, t.text FROM translations t '
          'JOIN ayahs a ON a.number = t.ayah_number '
          'WHERE a.surah = ? AND t.edition = ? '
          'ORDER BY a.number_in_surah',
          [surah, edition],
        ))
          r['n'] as int: r['text'] as String
      };

  List<Edition> readEditions({String? format, String? type}) {
    final where = <String>[];
    final args = <Object?>[];
    if (format != null) {
      where.add('format = ?');
      args.add(format);
    }
    if (type != null) {
      where.add('type = ?');
      args.add(type);
    }
    final clause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    return db
        .select('SELECT * FROM editions $clause ORDER BY english_name', args)
        .map(_editionOf)
        .toList(growable: false);
  }

  static Surah _surahOf(Row r) => Surah(
        number: r['number'] as int,
        nameAr: r['name_ar'] as String,
        nameEn: r['name_en'] as String,
        nameEnTranslation: r['name_en_translation'] as String,
        revelationType: r['revelation_type'] as String,
        ayahCount: r['ayah_count'] as int,
      );

  static Ayah _ayahOf(Row r) => Ayah(
        number: r['number'] as int,
        surah: r['surah'] as int,
        numberInSurah: r['number_in_surah'] as int,
        juz: r['juz'] as int,
        page: r['page'] as int,
        hizbQuarter: r['hizb_quarter'] as int,
        ruku: r['ruku'] as int,
        manzil: r['manzil'] as int,
        sajda: (r['sajda'] as int) == 1,
        sajdaObligatory: r['sajda_obligatory'] == null
            ? null
            : (r['sajda_obligatory'] as int) == 1,
        textAr: r['text_ar'] as String,
      );

  static Edition _editionOf(Row r) => Edition(
        identifier: r['identifier'] as String,
        language: r['language'] as String,
        name: r['name'] as String,
        englishName: r['english_name'] as String,
        format: r['format'] as String,
        type: r['type'] as String,
        direction: r['direction'] as String?,
        bitrate: r['bitrate'] as int?,
      );

  /// Bookmarked ayah numbers, in Quran order.
  List<int> readBookmarks() => db
      .select('SELECT ayah_number FROM bookmarks ORDER BY ayah_number')
      .map((r) => r['ayah_number'] as int)
      .toList(growable: false);

  bool isBookmarked(int ayahNumber) => db
      .select('SELECT 1 FROM bookmarks WHERE ayah_number = ?', [ayahNumber])
      .isNotEmpty;

  void addBookmark(int ayahNumber) => db.execute(
        'INSERT OR REPLACE INTO bookmarks VALUES (?, ?, NULL)',
        [ayahNumber, DateTime.now().millisecondsSinceEpoch],
      );

  void removeBookmark(int ayahNumber) =>
      db.execute('DELETE FROM bookmarks WHERE ayah_number = ?', [ayahNumber]);

  /// Ayahs addressed by their global number rather than by surah — how the
  /// daily pick arrives, scattered across the Quran.
  List<Ayah> readAyahsByNumber(List<int> numbers) {
    if (numbers.isEmpty) return const [];
    final holes = List.filled(numbers.length, '?').join(',');
    return db
        .select('SELECT * FROM ayahs WHERE number IN ($holes) ORDER BY number',
            numbers)
        .map(_ayahOf)
        .toList(growable: false);
  }

  Map<int, String> readTranslationsByNumber(List<int> numbers, String edition) {
    if (numbers.isEmpty) return const {};
    final holes = List.filled(numbers.length, '?').join(',');
    return {
      for (final r in db.select(
        'SELECT ayah_number n, text FROM translations '
        'WHERE edition = ? AND ayah_number IN ($holes)',
        [edition, ...numbers],
      ))
        r['n'] as int: r['text'] as String
    };
  }

  /// The ayah numbers stored for one day, or null when that day has never been
  /// asked for. Stored as a comma-separated list: a handful of small integers,
  /// read whole or not at all.
  List<int>? readDailyAyahs(String date) {
    final rows = db.select(
        'SELECT ayah_numbers FROM daily_ayahs WHERE date = ?', [date]);
    if (rows.isEmpty) return null;
    return [
      for (final n in (rows.first['ayah_numbers'] as String).split(','))
        int.parse(n)
    ];
  }

  void writeDailyAyahs(String date, List<int> ayahNumbers) => db.execute(
        'INSERT OR REPLACE INTO daily_ayahs VALUES (?, ?)',
        [date, ayahNumbers.join(',')],
      );

  /// Every day already generated, newest first. The calendar reads this.
  List<String> readDailyDates() => db
      .select('SELECT date FROM daily_ayahs ORDER BY date DESC')
      .map((r) => r['date'] as String)
      .toList(growable: false);

  String? readSetting(String key) {
    final rows = db.select('SELECT value FROM settings WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  void writeSetting(String key, String value) => db.execute(
        'INSERT OR REPLACE INTO settings VALUES (?, ?)',
        [key, value],
      );
}
