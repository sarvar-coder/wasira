package uz.wasira.ui.daily

/**
 * What the app says about itself, and who it owes. Ported from
 * lib/domain/app_info.dart. The version is read from the installed package at
 * runtime rather than repeated here, so it cannot drift from versionName.
 */
object AboutConstants {
    /** The Quran text and every translation come from one free, keyless API. */
    const val QURAN_SOURCE = "alquran.cloud"
    const val QURAN_SOURCE_URL = "https://alquran.cloud"

    /**
     * The SIL Open Font License requires this notice to travel with the font.
     * Left in English: a licence notice is not a thing to translate. The full
     * licence ships as assets/OFL.txt.
     */
    const val FONT_NAME = "Amiri Quran"
    const val FONT_COPYRIGHT =
        "Copyright 2010-2022 The Amiri Project Authors (https://github.com/aliftype/amiri)."
    const val FONT_LICENCE = "SIL Open Font License, Version 1.1"
    const val FONT_LICENCE_URL = "https://openfontlicense.org"
}

/** How an ayah is cited everywhere it leaves the app: 2:255, not "Al-Baqarah 255". */
fun ayahReference(surah: Int, numberInSurah: Int): String = "$surah:$numberInSurah"

/**
 * What Copy puts on the clipboard: Arabic, then the translation, then the
 * citation. The Arabic goes out byte for byte — what leaves the app is what the
 * API sent.
 */
fun ayahCitation(
    arabic: String,
    translation: String?,
    surahName: String,
    surah: Int,
    numberInSurah: Int,
): String = buildList {
    add(arabic)
    if (!translation.isNullOrEmpty()) add(translation)
    add("— $surahName ${ayahReference(surah, numberInSurah)}")
}.joinToString("\n\n")
