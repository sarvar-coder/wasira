import 'package:flutter_test/flutter_test.dart';
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
}
