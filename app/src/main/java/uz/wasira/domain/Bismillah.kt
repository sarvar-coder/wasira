package uz.wasira.domain

/*
 * Separating the opening Bismillah from ayah 1.
 *
 * The API concatenates the Bismillah onto the front of ayah 1 for most surahs,
 * so `quran-uthmani` returns 2:1 as the Bismillah followed by الٓمٓ while every
 * translation returns only "Alif, Lam, Meem". This is the single sanctioned
 * exception to leaving Quran text untouched, and it is segmentation rather than
 * alteration: the API joined two distinct things and this pulls them apart.
 *
 * The constants are written as \u escapes so no editor or tool can silently
 * normalise them. BismillahTest pins them against the real API response.
 */

/** Byte-for-byte the prefix `quran-uthmani` prepends to ayah 1. */
const val BISMILLAH_UTHMANI: String =
    "بِسْمِ " +
        "ٱللَّهِ " +
        "ٱلرَّحْمَٰنِ " +
        "ٱلرَّحِيمِ"

/**
 * A malformed spelling the API sends for At-Tin (95) and Al-Qadr (97) only: a
 * spurious U+0651 SHADDA on the first beh. Recognised so those two surahs split
 * like every other; the header returned is always the canonical spelling.
 * Reported upstream at islamic-network/.github#2.
 */
private const val BISMILLAH_WITH_SPURIOUS_SHADDA: String =
    "بِّسْمِ " +
        "ٱللَّهِ " +
        "ٱلرَّحْمَٰنِ " +
        "ٱلرَّحِيمِ"

/** Zero-width no-break space. The API prefixes it to 1:1. */
private const val BOM = "﻿"

/** Al-Fatiha, where the Bismillah is genuinely ayah 1 rather than an opening. */
private const val SURAH_WHERE_BISMILLAH_IS_AYAH_ONE = 1

/** At-Tawbah, the one surah with no Bismillah at all. */
private const val SURAH_WITHOUT_BISMILLAH = 9

data class BismillahSplit(
    /**
     * The Bismillah to render above the surah, or null when there is none to
     * render separately: it is ayah 1 itself, the surah has none, or this is
     * not ayah 1.
     */
    val header: String?,
    /** The ayah's own text, with any opening Bismillah and BOM removed. */
    val text: String,
)

/**
 * Splits the opening Bismillah off [text] when it is prepended to ayah 1.
 *
 * Leaves the text untouched whenever the prefix is not found, so an edition
 * whose orthography differs renders whole rather than mangled.
 */
fun splitOpeningBismillah(
    surah: Int,
    numberInSurah: Int,
    text: String,
    bismillah: String = BISMILLAH_UTHMANI,
): BismillahSplit {
    val stripped = text.removePrefix(BOM)

    // Only ever ayah 1. This alone protects 27:30, where the Bismillah is
    // genuine ayah content inside Sulayman's letter.
    if (numberInSurah != 1) return BismillahSplit(header = null, text = stripped)

    // In Al-Fatiha the Bismillah IS the ayah; At-Tawbah has none.
    if (surah == SURAH_WHERE_BISMILLAH_IS_AYAH_ONE || surah == SURAH_WITHOUT_BISMILLAH) {
        return BismillahSplit(header = null, text = stripped)
    }

    val candidates =
        if (bismillah == BISMILLAH_UTHMANI) listOf(BISMILLAH_UTHMANI, BISMILLAH_WITH_SPURIOUS_SHADDA)
        else listOf(bismillah)

    for (candidate in candidates) {
        val prefix = "$candidate "
        if (stripped.startsWith(prefix)) {
            return BismillahSplit(header = bismillah, text = stripped.substring(prefix.length))
        }
    }
    return BismillahSplit(header = null, text = stripped)
}

/** [splitOpeningBismillah] applied to a whole ayah; returns it unchanged when there is nothing to split. */
fun Ayah.withoutOpeningBismillah(): Ayah {
    val split = splitOpeningBismillah(surah = surah.number, numberInSurah = numberInSurah, text = text)
    return if (split.text == text) this else copy(text = split.text)
}
