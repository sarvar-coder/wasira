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

/**
 * One hadith from HadeethEnc. Every string is exactly as sent: its terms forbid
 * modifying, adding to or deleting from the content.
 */
data class Hadith(
    /** HadeethEnc's id. A string in every response. */
    val id: String,
    /** The language [translation], [explanation] and the rest are in. */
    val language: String,
    /** Every language HadeethEnc has this hadith in. */
    val languages: List<String>,
    /** The Arabic text. */
    val arabic: String,
    /** The hadith in [language]; null when [language] is Arabic, because [arabic] already is. */
    val translation: String?,
    /** Who narrated or collected it: "Narrated by At-Tirmidhi". */
    val attribution: String,
    /** Its authenticity grade: "Authentic". */
    val grade: String,
    val explanation: String,
    /** What the hadith teaches, one point each. */
    val hints: List<String>,
)

/** Today's hadith, as cached in hadith.json. */
data class DailyHadith(
    /** Local day key, YYYY-MM-DD. */
    val date: String,
    val hadith: Hadith,
)
