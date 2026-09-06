import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wasira/data/repositories/bookmark_repository.dart';
import 'package:wasira/data/services/database_service.dart';
import 'package:wasira/domain/ayah_citation.dart';

void main() {
  group('citing an ayah', () {
    // 2:255, Ayat al-Kursi, as the API returns it.
    const arabic = 'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ٱلْحَىُّ ٱلْقَيُّومُ';

    test('reads Arabic, translation, then the reference', () {
      expect(
        ayahCitation(
          arabic: arabic,
          translation: 'Allah - there is no deity except Him',
          surahName: 'Al-Baqara',
          surah: 2,
          numberInSurah: 255,
        ),
        '$arabic\n\n'
        'Allah - there is no deity except Him\n\n'
        '— Al-Baqara 2:255',
      );
    });

    test('leaves the Arabic byte for byte', () {
      // What leaves the app is what the API sent: no reflow, no normalising,
      // no diacritics stripped.
      expect(
        ayahCitation(
          arabic: arabic,
          surahName: 'Al-Baqara',
          surah: 2,
          numberInSurah: 255,
        ).startsWith(arabic),
        isTrue,
      );
    });

    test('omits the translation rather than leaving a blank line', () {
      for (final empty in [null, '']) {
        final text = ayahCitation(
          arabic: arabic,
          translation: empty,
          surahName: 'Al-Baqara',
          surah: 2,
          numberInSurah: 255,
        );
        expect(text, '$arabic\n\n— Al-Baqara 2:255');
      }
    });

    test('the reference is surah:ayah, not the global number', () {
      // 2:255 is global ayah 262; the citation people recognise is 2:255.
      expect(ayahReference(2, 255), '2:255');
      expect(ayahReference(1, 1), '1:1');
      expect(ayahReference(114, 6), '114:6');
    });
  });

  group('bookmarks', () {
    late Database raw;
    late BookmarkRepository bookmarks;

    setUp(() {
      raw = sqlite3.openInMemory();
      bookmarks = BookmarkRepository(DatabaseService(raw)..migrate());
    });

    tearDown(() => raw.close());

    test('toggle saves, then removes, and reports which', () {
      expect(bookmarks.toggle(262), isTrue);
      expect(bookmarks.contains(262), isTrue);

      expect(bookmarks.toggle(262), isFalse);
      expect(bookmarks.contains(262), isFalse);
    });

    test('saving the same ayah twice keeps one bookmark', () {
      bookmarks.toggle(262);
      bookmarks.db.addBookmark(262);

      expect(bookmarks.all, [262]);
    });

    test('are listed in Quran order, not the order they were saved', () {
      for (final n in [6236, 1, 262, 100]) {
        bookmarks.toggle(n);
      }

      expect(bookmarks.all, [1, 100, 262, 6236]);
    });

    test('removing one that was never saved is not an error', () {
      expect(() => bookmarks.db.removeBookmark(999), returnsNormally);
      expect(bookmarks.all, isEmpty);
    });
  });
}
