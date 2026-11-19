package uz.wasira.data

import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.int
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import uz.wasira.domain.Ayah
import uz.wasira.domain.Edition
import uz.wasira.domain.Surah

/**
 * alquran.cloud. Holds no state.
 *
 * Response shapes mirror the live API, including the quirks that break naive
 * parsing: `sajda` is `false` or an object, a single edition may come back as
 * an object rather than a list, and Arabic text must survive as UTF-8 bytes.
 */
class AlquranApi(
    private val client: OkHttpClient,
    private val baseUrl: HttpUrl,
) : QuranApi {
    /** Every text translation, for the picker. */
    override suspend fun translations(): List<Edition> {
        val data = get("edition?format=text&type=translation")
        return parse("translations") { data.jsonArray.map { parseEdition(it.jsonObject) } }
    }

    /**
     * One ayah, in Arabic and in a translation, in a single request: the whole
     * of a day's network use. Each row carries its surah inline.
     */
    override suspend fun ayah(number: Int, translation: String?): FetchedAyah {
        val editions = listOfNotNull(ARABIC_EDITION, translation?.takeIf { it != ARABIC_EDITION })
        val data = get("ayah/$number/editions/${editions.joinToString(",")}")

        return parse("ayah $number") {
            // A single edition can come back unwrapped; asking for two always yields a list.
            val rows = (if (data is JsonArray) data.toList() else listOf(data)).map { it.jsonObject }
            fun rowFor(edition: String) = rows.firstOrNull { row ->
                (row["edition"] as? JsonObject)?.get("identifier")?.stringOrNull() == edition
            }

            val arabic = rowFor(ARABIC_EDITION)
                ?: throw AlquranApiException("ayah $number came back without $ARABIC_EDITION")
            val translationRow = translation?.takeIf { it != ARABIC_EDITION }?.let(::rowFor)

            FetchedAyah(
                ayah = parseAyah(arabic),
                translation = translationRow?.get("text")?.stringOrNull(),
                translationDirection = (translationRow?.get("edition") as? JsonObject)
                    ?.get("direction")?.stringOrNull(),
            )
        }
    }

    /** The `data` field of a successful response. */
    private suspend fun get(path: String): JsonElement = withContext(Dispatchers.IO) {
        val url = baseUrl.resolve(path) ?: throw AlquranApiException("bad path $path")
        val bytes = try {
            client.newCall(Request.Builder().url(url).build()).execute().use { response ->
                if (response.code != 200) throw AlquranApiException("GET $path returned ${response.code}")
                response.body.bytes()
            }
        } catch (e: IOException) {
            // OkHttp's call timeout surfaces as an InterruptedIOException.
            throw AlquranApiException("GET $path failed: ${e.message}", e)
        }

        val body = try {
            Json.parseToJsonElement(bytes.toString(Charsets.UTF_8))
        } catch (e: Exception) {
            throw AlquranApiException("GET $path returned a body that is not JSON", e)
        }
        if (body !is JsonObject) throw AlquranApiException("GET $path returned a body that is not an object")
        val code = (body["code"] as? JsonPrimitive)?.intOrNull
        if (code != 200) throw AlquranApiException("GET $path returned body code ${code ?: "?"}")
        body["data"] ?: throw AlquranApiException("GET $path returned no data")
    }

    /** Any shape surprise in a 200 response is a malformed body, not a crash. */
    private inline fun <T> parse(what: String, block: () -> T): T =
        try {
            block()
        } catch (e: AlquranApiException) {
            throw e
        } catch (e: Exception) {
            throw AlquranApiException("$what: malformed body (${e.message})", e)
        }

    companion object {
        const val BASE_URL = "https://api.alquran.cloud/v1/"

        /** Arabic, in the Uthmani script the app renders. */
        const val ARABIC_EDITION = "quran-uthmani"

        private fun JsonElement.stringOrNull(): String? =
            (this as? JsonPrimitive)?.takeIf { it.isString }?.content

        private fun JsonObject.string(key: String): String =
            getValue(key).stringOrNull() ?: throw IllegalArgumentException("$key is not a string")

        private fun parseEdition(json: JsonObject) = Edition(
            identifier = json.string("identifier"),
            language = json.string("language"),
            name = json.string("name"),
            englishName = json.string("englishName"),
            format = json.string("format"),
            type = json.string("type"),
            direction = json["direction"]?.stringOrNull(),
        )

        private fun parseSurah(json: JsonObject) = Surah(
            number = json.getValue("number").jsonPrimitive.int,
            nameAr = json.string("name"),
            nameEn = json.string("englishName"),
            nameEnTranslation = json.string("englishNameTranslation"),
            revelationType = json.string("revelationType"),
            ayahCount = json["numberOfAyahs"]?.jsonPrimitive?.int ?: json.getValue("ayahs").jsonArray.size,
        )

        private fun parseAyah(json: JsonObject): Ayah {
            // `false` for ordinary ayahs, an object {id, recommended, obligatory} for the 15 sajda ayahs.
            val sajda = json["sajda"]
            val sajdaObject = sajda as? JsonObject
            return Ayah(
                number = json.getValue("number").jsonPrimitive.int,
                numberInSurah = json.getValue("numberInSurah").jsonPrimitive.int,
                surah = parseSurah(json.getValue("surah").jsonObject),
                // Exactly as sent, BOM included. The Bismillah split happens in the domain.
                text = json.string("text"),
                sajda = sajdaObject != null || (sajda as? JsonPrimitive)?.booleanOrNull == true,
                sajdaObligatory = (sajdaObject?.get("obligatory") as? JsonPrimitive)?.booleanOrNull,
            )
        }
    }
}
