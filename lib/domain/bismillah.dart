/// Separating the opening Bismillah from ayah 1.
///
/// The API concatenates the Bismillah onto the front of ayah 1 for most surahs,
/// so `quran-uthmani` returns 2:1 as "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ الٓمٓ"
/// while every translation returns only "Alif, Lam, Meem". Al-Baqarah's first
/// ayah is الٓمٓ alone, so the two must be separated before display.
///
/// This is the single sanctioned exception to leaving Quran text untouched, and
/// it is segmentation rather than alteration: the API joined two distinct
/// things and this pulls them apart again.
library;

/// Byte-for-byte the prefix `quran-uthmani` prepends. A test pins it against
/// the real API response, so a change upstream fails loudly rather than
/// silently disabling the split.
const bismillahUthmani = 'بِسْمِ '
    'ٱللَّهِ '
    'ٱلرَّحْمَٰنِ '
    'ٱلرَّحِيمِ';

/// A malformed spelling the API sends for At-Tin (95) and Al-Qadr (97) only:
/// it carries a spurious U+0651 SHADDA on the beh, giving a doubled beh where
/// the Bismillah has none. Recognised so those two surahs split like every
/// other; the header rendered is always the canonical spelling above.
///
/// The header is surah chrome derived from the data, not ayah text, and the
/// ayah text left after the split is byte-untouched either way.
const _bismillahWithSpuriousShadda = '\u0628\u0651\u0650\u0633\u0652\u0645\u0650 '
    '\u0671\u0644\u0644\u0651\u064E\u0647\u0650 '
    '\u0671\u0644\u0631\u0651\u064E\u062D\u0652\u0645\u064E\u0670\u0646\u0650 '
    '\u0671\u0644\u0631\u0651\u064E\u062D\u0650\u064A\u0645\u0650';

/// Zero-width no-break space. The API prefixes it to 1:1 only.
const _bom = '﻿';

/// Al-Fatiha, where the Bismillah is genuinely ayah 1 rather than an opening.
const _surahWhereBismillahIsAyahOne = 1;

/// At-Tawbah, the one surah with no Bismillah at all.
const _surahWithoutBismillah = 9;

class BismillahSplit {
  const BismillahSplit({required this.header, required this.text});

  /// The Bismillah to render above the surah, or null when there is none to
  /// render separately — either because it is ayah 1 itself, because the surah
  /// has none, or because this is not ayah 1.
  final String? header;

  /// The ayah's own text, with any opening Bismillah and BOM removed.
  final String text;
}

/// Splits the opening Bismillah off [text] when it is prepended to ayah 1.
///
/// Leaves the text untouched whenever the prefix is not found, so an edition
/// whose orthography differs renders whole rather than mangled.
BismillahSplit splitOpeningBismillah({
  required int surah,
  required int numberInSurah,
  required String text,
  String bismillah = bismillahUthmani,
}) {
  final stripped = text.startsWith(_bom) ? text.substring(_bom.length) : text;

  // Only ever ayah 1. This alone protects 27:30, where the Bismillah is
  // genuine ayah content inside Sulayman's letter.
  if (numberInSurah != 1) {
    return BismillahSplit(header: null, text: stripped);
  }

  // In Al-Fatiha the Bismillah IS the ayah; removing it would leave nothing.
  if (surah == _surahWhereBismillahIsAyahOne ||
      surah == _surahWithoutBismillah) {
    return BismillahSplit(header: null, text: stripped);
  }

  final candidates = bismillah == bismillahUthmani
      ? const [bismillahUthmani, _bismillahWithSpuriousShadda]
      : [bismillah];

  for (final candidate in candidates) {
    final prefix = '$candidate ';
    if (stripped.startsWith(prefix)) {
      return BismillahSplit(
        header: bismillah,
        text: stripped.substring(prefix.length),
      );
    }
  }

  return BismillahSplit(header: null, text: stripped);
}
