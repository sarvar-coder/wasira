package uz.wasira.data

import uz.wasira.domain.Ayah
import uz.wasira.domain.DailyAyah
import uz.wasira.domain.DailyHadith
import uz.wasira.domain.Edition
import uz.wasira.domain.Hadith

/** Thrown for timeouts, non-200 status, non-200 body `code`, and malformed bodies. */
class AlquranApiException(message: String, cause: Throwable? = null) : Exception(message, cause)

/** What one daily request returns: the Arabic row plus the translation row, if any. */
data class FetchedAyah(
    val ayah: Ayah,
    val translation: String?,
    val translationDirection: String?,
)

/** alquran.cloud. Implemented by [AlquranApi]. */
interface QuranApi {
    /** GET /edition?format=text&type=translation */
    suspend fun translations(): List<Edition>

    /** GET /ayah/{n}/editions/quran-uthmani,{translation}. Arabic text returned exactly as sent (BOM included). */
    suspend fun ayah(number: Int, translation: String?): FetchedAyah
}

data class Settings(
    val translationEdition: String?,
    val translationName: String?,
    /** One of [SettingsRepository.ARABIC_SIZES]. */
    val arabicFontSize: Int,
    /** Exactly five, minutes after local midnight, each 0..1439. */
    val reminderTimes: List<Int>,
) {
    /** Name to show; falls back to the identifier. */
    val translationLabel: String get() = translationName ?: translationEdition.orEmpty()
}

/** Persisted user settings. Implemented by [SettingsRepository]. */
interface SettingsSource {
    suspend fun read(): Settings
    suspend fun setTranslation(identifier: String, name: String?)
    /** Ignores values not in [SettingsRepository.ARABIC_SIZES]. */
    suspend fun setArabicFontSize(size: Int)
    /** Clamps [minutes] to 0..1439; [slot] is 0..4. */
    suspend fun setReminderTime(slot: Int, minutes: Int)
}

/** Source of today's ayah. Implemented by [DailyRepository]. */
interface DailySource {
    /** Cached ayah if it is today's and for the current translation; otherwise draws and fetches a new one. */
    suspend fun today(): DailyAyah
}

/** Schedules the five daily reminders. Implemented in data/reminders. */
interface ReminderScheduler {
    /** Cancel all and arm one repeating-daily reminder per time (minutes after local midnight). */
    fun schedule(times: List<Int>)

    /** True if the app may post notifications (POST_NOTIFICATIONS on API 33+). */
    fun canNotify(): Boolean
}

/** Thrown for timeouts, unexpected status codes and malformed HadeethEnc bodies. */
class HadeethEncException(message: String, cause: Throwable? = null) : Exception(message, cause)

/** One top-level HadeethEnc category and how many hadiths it lists. */
data class HadithCategory(val id: String, val count: Int)

/** One entry of a category listing: enough to fetch it, and the languages it exists in. */
data class HadithEntry(val id: String, val languages: List<String>)

/** HadeethEnc. Implemented by [HadeethEncApi]. */
interface HadithApi {
    /** GET /categories/roots/?language={language} */
    suspend fun roots(language: String): List<HadithCategory>

    /** GET /hadeeths/list/?language=..&category_id=..&page={page}&per_page=1. Null past the last page. */
    suspend fun entry(language: String, category: String, page: Int): HadithEntry?

    /**
     * GET /hadeeths/one/?language=..&id=.. with every string exactly as sent. Null
     * when the hadith does not exist in [language]: HadeethEnc answers that with
     * a 404 and an empty body.
     */
    suspend fun hadith(id: String, language: String): Hadith?
}

/** Source of today's hadith. Implemented by [HadithRepository]. */
interface HadithSource {
    /**
     * The cached hadith if it is today's and in the right language; otherwise
     * draws a new one. Shown in [language] when HadeethEnc has it, in English
     * when it does not.
     */
    suspend fun today(language: String): DailyHadith
}
