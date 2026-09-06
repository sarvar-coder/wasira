/// How a reciter's audio is published, which decides both the URL shape and
/// which playback controls can work at all.
enum RecitationLayout {
  /// One file per ayah. Required for following along ayah by ayah and for
  /// repeating a single ayah.
  verseByVerse,

  /// One file per surah. Cannot address individual ayahs.
  surahBySurah,
}

/// A reciter the app offers.
///
/// The list is fixed and chosen by name rather than filtered from the API at
/// runtime. Of the API's 190 audio editions, 14 are people reading a
/// *translation* aloud; that is not recitation and is never offered here.
class Reciter {
  const Reciter({
    required this.edition,
    required this.name,
    required this.layout,
    required this.bitrate,
  });

  final String edition;
  final String name;
  final RecitationLayout layout;

  /// Per reciter, never assumed. 128k is not universal across the API's
  /// editions, and a wrong bitrate 403s on every request.
  final int bitrate;

  bool get isVerseByVerse => layout == RecitationLayout.verseByVerse;

  /// Ayah-level features are impossible without one file per ayah.
  bool get supportsAyahControls => isVerseByVerse;

  static const alafasy = Reciter(
    edition: 'ar.alafasy',
    name: 'Mishary Rashid Alafasy',
    layout: RecitationLayout.verseByVerse,
    bitrate: 128,
  );

  static const husaryMujawwad = Reciter(
    edition: 'ar.husarymujawwad',
    name: 'Husary (Mujawwad)',
    layout: RecitationLayout.verseByVerse,
    bitrate: 128,
  );

  static const luhaidan = Reciter(
    edition: 'ar.muhammadalluhaidan',
    name: 'Muhammad al-Luhaidan',
    layout: RecitationLayout.surahBySurah,
    bitrate: 128,
  );

  static const all = [alafasy, husaryMujawwad, luhaidan];

  static Reciter byEdition(String edition) =>
      all.firstWhere((r) => r.edition == edition);
}
