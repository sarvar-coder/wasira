import 'reciter.dart';

/// Builds recitation URLs.
///
/// Nothing here is fetched from the API: for verse-by-verse editions the URL is
/// computed, and for surah-by-surah ones the API returns `audio: null`, so the
/// URL has to be built by hand regardless.
class AudioUrl {
  const AudioUrl._();

  static const host = 'https://cdn.islamic.network/quran';

  /// One ayah of a verse-by-verse reciter, addressed by its **global** ayah
  /// number, 1 to 6236 — not its number within the surah.
  static Uri ayah(Reciter reciter, int ayahNumber) {
    if (!reciter.isVerseByVerse) {
      throw ArgumentError(
          '${reciter.edition} publishes whole surahs; use AudioUrl.surah');
    }
    _check(ayahNumber, 1, 6236, 'ayah number');
    return Uri.parse('$host/audio/${reciter.bitrate}/${reciter.edition}/$ayahNumber.mp3');
  }

  /// A whole surah, for a surah-by-surah reciter. Note the different path
  /// segment: `audio-surah`, not `audio`.
  static Uri surah(Reciter reciter, int surahNumber) {
    if (reciter.isVerseByVerse) {
      throw ArgumentError(
          '${reciter.edition} publishes single ayahs; use AudioUrl.ayah');
    }
    _check(surahNumber, 1, 114, 'surah number');
    return Uri.parse(
        '$host/audio-surah/${reciter.bitrate}/${reciter.edition}/$surahNumber.mp3');
  }

  static void _check(int value, int min, int max, String what) {
    if (value < min || value > max) {
      throw RangeError.range(value, min, max, what);
    }
  }
}
