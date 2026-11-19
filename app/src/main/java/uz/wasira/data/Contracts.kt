package uz.wasira.data

import uz.wasira.domain.Ayah
import uz.wasira.domain.DailyAyah
import uz.wasira.domain.Edition

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
