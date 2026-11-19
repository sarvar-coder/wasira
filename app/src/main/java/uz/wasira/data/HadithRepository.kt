package uz.wasira.data

import java.time.LocalDate
import kotlin.random.Random
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonArray
import uz.wasira.data.HadeethEncApi.Companion.ENGLISH
import uz.wasira.domain.DailyHadith
import uz.wasira.domain.Hadith
import uz.wasira.domain.dayKey

/**
 * The hadith of the day, in hadith.json.
 *
 * Today only, like the ayah: the moment the cached date is not today it is
 * thrown away and a new one is drawn. Kept apart from daily.json so that
 * changing the Quran translation, which refetches the ayah, never redraws the
 * hadith.
 */
class HadithRepository(
    private val api: HadithApi,
    private val store: LocalStore,
    private val today: () -> LocalDate = LocalDate::now,
    private val random: Random = Random.Default,
) : HadithSource {
    override suspend fun today(language: String): DailyHadith {
        val key = dayKey(today.invoke())

        val cached = withContext(Dispatchers.IO) { cached(key) }
        if (cached != null) {
            // Compared with what was asked, not with what is shown: an English
            // stand-in for a missing Uzbek copy is the answer, not a reason to retry.
            if (cached.asked == language) return cached.daily
            // The UI language changed today: the same hadith, in the new language.
            val hadith = cached.daily.hadith
            return save(key, language, fetch(hadith.id, shownIn(language, hadith.languages)))
        }

        // Yesterday's entry is dropped first, so a failed draw cannot leave it on screen.
        withContext(Dispatchers.IO) { store.clear() }

        val entry = draw()
        return save(key, language, fetch(entry.id, shownIn(language, entry.languages)))
    }

    /**
     * A random hadith from the English listing. HadeethEnc lists only by
     * category, so a category is picked weighted by its size and then a page
     * within it. Categories overlap, so a hadith filed under two is slightly
     * likelier; like the ayah, the draw need not be uniform.
     */
    private suspend fun draw(): HadithEntry {
        val roots = api.roots(ENGLISH).filter { it.count > 0 }
        if (roots.isEmpty()) throw HadeethEncException("no categories")
        var n = random.nextInt(roots.sumOf { it.count })
        for (root in roots) {
            if (n < root.count) {
                return api.entry(ENGLISH, root.id, n + 1)
                    ?: throw HadeethEncException("category ${root.id} has no page ${n + 1}")
            }
            n -= root.count
        }
        error("unreachable: n is below the sum of the counts")
    }

    /** English stands in when the hadith exists in English but not in the wanted language. */
    private suspend fun fetch(id: String, language: String): Hadith =
        api.hadith(id, language)
            ?: language.takeIf { it != ENGLISH }?.let { api.hadith(id, ENGLISH) }
            ?: throw HadeethEncException("hadith $id is in neither $language nor $ENGLISH")

    private suspend fun save(key: String, asked: String, hadith: Hadith): DailyHadith {
        val daily = DailyHadith(key, hadith)
        withContext(Dispatchers.IO) { store.write(JsonObject(toJson(daily) + (ASKED to JsonPrimitive(asked)))) }
        return daily
    }

    /** Today's stored hadith and the UI language it was fetched for. */
    private class Cached(val daily: DailyHadith, val asked: String?)

    private fun cached(key: String): Cached? {
        val json = store.read()
        if ((json["date"] as? JsonPrimitive)?.content != key) return null
        return try {
            Cached(fromJson(json), (json[ASKED] as? JsonPrimitive)?.content)
        } catch (_: Exception) {
            null
        }
    }

    companion object {
        /** The UI language a stored hadith was fetched for, which may not be the one it is in. */
        private const val ASKED = "asked"

        /** [language] if HadeethEnc has the hadith in it, otherwise English. */
        fun shownIn(language: String, available: List<String>): String =
            if (language in available) language else ENGLISH

        private fun JsonObject.text(key: String): String =
            (getValue(key) as JsonPrimitive).takeIf { it.isString }?.content
                ?: throw IllegalArgumentException("$key missing")

        private fun JsonObject.texts(key: String): List<String> =
            getValue(key).jsonArray.map { (it as JsonPrimitive).content }

        private fun strings(values: List<String>) = JsonArray(values.map(::JsonPrimitive))

        internal fun toJson(daily: DailyHadith): JsonObject {
            val h = daily.hadith
            return JsonObject(
                linkedMapOf<String, JsonElement>(
                    "date" to JsonPrimitive(daily.date),
                    "id" to JsonPrimitive(h.id),
                    "language" to JsonPrimitive(h.language),
                    "languages" to strings(h.languages),
                    "arabic" to JsonPrimitive(h.arabic),
                    "translation" to (h.translation?.let(::JsonPrimitive) ?: JsonNull),
                    "attribution" to JsonPrimitive(h.attribution),
                    "grade" to JsonPrimitive(h.grade),
                    "explanation" to JsonPrimitive(h.explanation),
                    "hints" to strings(h.hints),
                ),
            )
        }

        internal fun fromJson(json: JsonObject) = DailyHadith(
            date = json.text("date"),
            hadith = Hadith(
                id = json.text("id"),
                language = json.text("language"),
                languages = json.texts("languages"),
                arabic = json.text("arabic"),
                translation = (json["translation"] as? JsonPrimitive)?.takeIf { it.isString }?.content,
                attribution = json.text("attribution"),
                grade = json.text("grade"),
                explanation = json.text("explanation"),
                hints = json.texts("hints"),
            ),
        )
    }
}
