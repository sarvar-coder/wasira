import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wasira/data/repositories/settings_repository.dart';
import 'package:wasira/data/services/database_service.dart';

void main() {
  late Database db;
  late SettingsRepository settings;

  setUp(() {
    db = sqlite3.openInMemory();
    settings = SettingsRepository(DatabaseService(db)..migrate());
  });
  tearDown(() => db.close());

  test('a fresh install reads the default size', () {
    expect(settings.arabicFontSize, SettingsRepository.defaultArabicSize);
  });

  test('a chosen size survives being read back', () {
    settings.setArabicFontSize(34);

    expect(settings.arabicFontSize, 34);
  });

  test('an offered size round-trips for every option', () {
    for (final size in SettingsRepository.arabicSizes) {
      settings.setArabicFontSize(size);
      expect(settings.arabicFontSize, size);
    }
  });

  test('a size outside the offered set is refused, not stored', () {
    settings.setArabicFontSize(34);

    settings.setArabicFontSize(200);

    expect(settings.arabicFontSize, 34, reason: 'must keep the last valid one');
  });

  test('a corrupt stored value falls back rather than rendering at it', () {
    DatabaseService(db).writeSetting('arabic_font_size', 'not a number');

    expect(settings.arabicFontSize, SettingsRepository.defaultArabicSize);
  });
}
