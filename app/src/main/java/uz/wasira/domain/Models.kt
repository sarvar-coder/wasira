package uz.wasira.domain

/** A surah as the API sends it inline on every ayah row. */
data class Surah(
    val number: Int,
    val nameAr: String,
    val nameEn: String,
    val nameEnTranslation: String,
    val revelationType: String,
    val ayahCount: Int,
)

/** A text edition (translation or the Arabic itself). */
data class Edition(
    val identifier: String,
    val language: String,
    val name: String,
    val englishName: String,
    val format: String,
    val type: String,
    /** "rtl" / "ltr" as sent by the API; null when absent. */
    val direction: String?,
) {
    val isRtl: Boolean get() = direction == "rtl"
}

/** One ayah. [text] is the Arabic, never altered beyond the documented Bismillah split. */
data class Ayah(
    val number: Int,
    val numberInSurah: Int,
    val surah: Surah,
    val text: String,
    val sajda: Boolean,
    /** null when [sajda] is false. */
    val sajdaObligatory: Boolean?,
)

/** Today's ayah, as cached in daily.json. */
data class DailyAyah(
    /** Local day key, YYYY-MM-DD. */
    val date: String,
    /** The translation edition this was fetched with. */
    val edition: String?,
    /** Arabic already passed through the Bismillah split. */
    val ayah: Ayah,
    val translation: String?,
    /** "rtl" / "ltr" of the translation edition; null when unknown. */
    val translationDirection: String?,
) {
    val translationIsRtl: Boolean get() = translationDirection == "rtl"
}
