package uz.wasira.domain

/**
 * How an ayah is cited everywhere it leaves the app: surah:ayah, the form used
 * in print and in every other Quran app. 2:255, not "Al-Baqarah 255".
 */
fun ayahReference(surah: Int, numberInSurah: Int): String = "$surah:$numberInSurah"

/**
 * What copy and share put on the clipboard: Arabic, then the translation, then
 * the citation, the order it is read in. The Arabic goes out byte for byte.
 */
fun ayahCitation(
    arabic: String,
    surahName: String,
    surah: Int,
    numberInSurah: Int,
    translation: String? = null,
): String =
    buildList {
        add(arabic)
        if (!translation.isNullOrEmpty()) add(translation)
        add("— $surahName ${ayahReference(surah, numberInSurah)}")
    }.joinToString("\n\n")

/** [ayahCitation] for today's ayah. */
fun DailyAyah.citation(): String =
    ayahCitation(
        arabic = ayah.text,
        surahName = ayah.surah.nameEn,
        surah = ayah.surah.number,
        numberInSurah = ayah.numberInSurah,
        translation = translation,
    )
