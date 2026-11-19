package uz.wasira.data

import java.time.LocalDate
import kotlin.random.Random
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonPrimitive
import uz.wasira.domain.Ayah
import uz.wasira.domain.DailyAyah
import uz.wasira.domain.Surah
import uz.wasira.domain.dayKey
import uz.wasira.domain.withoutOpeningBismillah

/**
 * The ayah of the day, in daily.json.
 *
 * One ayah, held only for the day it belongs to. There is no yesterday and no
 * tomorrow: the moment the cached date is not today it is thrown away and a new
 * ayah is drawn.
 */
class DailyRepository(
    private val api: QuranApi,
    private val store: LocalStore,
    private val settings: SettingsSource,
    private val today: () -> LocalDate = LocalDate::now,
    private val random: Random = Random.Default,
) : DailySource {
    override suspend fun today(): DailyAyah {
        val key = dayKey(today.invoke())
        val edition = settings.read().translationEdition

        withContext(Dispatchers.IO) { cached(key, edition) }?.let { return it }

        // Yesterday's entry is dropped before the new one is fetched, so a failed
        // fetch cannot leave the wrong day's ayah on screen.
        withContext(Dispatchers.IO) { store.clear() }

        val fetched = api.ayah(random.nextInt(1, AYAHS_IN_QURAN + 1), edition)
        val daily = DailyAyah(
            date = key,
            edition = edition,
            // The API concatenates the Bismillah onto ayah 1, and a daily pick
            // lands there about once every fifty-five days.
            ayah = fetched.ayah.withoutOpeningBismillah(),
            translation = fetched.translation,
            translationDirection = fetched.translationDirection,
        )
        withContext(Dispatchers.IO) { store.write(toJson(daily)) }
        return daily
    }

    /**
     * The stored ayah, or null when there is none, it belongs to another day, it
     * was fetched against a translation since changed, or it does not parse.
     */
    private fun cached(key: String, edition: String?): DailyAyah? {
        val json = store.read()
        if (json.string("date") != key) return null
        if (json.string("edition") != edition) return null
        return try {
            fromJson(json)
        } catch (_: Exception) {
            null
        }
    }

    companion object {
        /** 1 to 6236. Fixed by the text itself, not by anything the app downloads. */
        const val AYAHS_IN_QURAN = 6236

        private fun JsonObject.string(key: String): String? =
            (this[key] as? JsonPrimitive)?.takeIf { it.isString }?.content

        private fun JsonObject.requireString(key: String): String =
            string(key) ?: throw IllegalArgumentException("$key missing")

        private fun JsonObject.int(key: String): Int = getValue(key).jsonPrimitive.int

        private fun str(value: String?): JsonElement = value?.let(::JsonPrimitive) ?: JsonNull

        internal fun toJson(daily: DailyAyah): JsonObject {
            val ayah = daily.ayah
            val surah = ayah.surah
            return JsonObject(
                linkedMapOf(
                    "date" to JsonPrimitive(daily.date),
                    "edition" to str(daily.edition),
                    "number" to JsonPrimitive(ayah.number),
                    "numberInSurah" to JsonPrimitive(ayah.numberInSurah),
                    "sajda" to JsonPrimitive(ayah.sajda),
                    "sajdaObligatory" to (ayah.sajdaObligatory?.let(::JsonPrimitive) ?: JsonNull),
                    "arabic" to JsonPrimitive(ayah.text),
                    "translation" to str(daily.translation),
                    "translationDirection" to str(daily.translationDirection),
                    "surahNumber" to JsonPrimitive(surah.number),
                    "surahNameAr" to JsonPrimitive(surah.nameAr),
                    "surahNameEn" to JsonPrimitive(surah.nameEn),
                    "surahNameEnTranslation" to JsonPrimitive(surah.nameEnTranslation),
                    "surahRevelationType" to JsonPrimitive(surah.revelationType),
                    "surahAyahCount" to JsonPrimitive(surah.ayahCount),
                ),
            )
        }

        internal fun fromJson(json: JsonObject) = DailyAyah(
            date = json.requireString("date"),
            edition = json.string("edition"),
            ayah = Ayah(
                number = json.int("number"),
                numberInSurah = json.int("numberInSurah"),
                surah = Surah(
                    number = json.int("surahNumber"),
                    nameAr = json.requireString("surahNameAr"),
                    nameEn = json.requireString("surahNameEn"),
                    nameEnTranslation = json.requireString("surahNameEnTranslation"),
                    revelationType = json.requireString("surahRevelationType"),
                    ayahCount = json.int("surahAyahCount"),
                ),
                text = json.requireString("arabic"),
                sajda = json.getValue("sajda").jsonPrimitive.boolean,
                sajdaObligatory = (json["sajdaObligatory"] as? JsonPrimitive)?.booleanOrNull,
            ),
            translation = json.string("translation"),
            translationDirection = json.string("translationDirection"),
        )
    }
}
