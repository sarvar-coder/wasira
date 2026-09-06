/// How an ayah is cited everywhere it leaves the app: surah:ayah, the form
/// used in print and in every other Quran app. 2:255, not "Al-Baqarah 255".
String ayahReference(int surah, int numberInSurah) => '$surah:$numberInSurah';

/// What copy and share put on the clipboard.
///
/// Arabic, then the translation, then the citation — the order it is read in.
/// The Arabic goes out byte for byte: not reflowed, not stripped of
/// diacritics, not normalised. What leaves the app is what the API sent.
String ayahCitation({
  required String arabic,
  required String surahName,
  required int surah,
  required int numberInSurah,
  String? translation,
}) =>
    [
      arabic,
      if (translation != null && translation.isNotEmpty) translation,
      '— $surahName ${ayahReference(surah, numberInSurah)}',
    ].join('\n\n');
