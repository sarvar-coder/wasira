package uz.wasira.data

import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import uz.wasira.domain.Hadith

/**
 * HadeethEnc.com, the Encyclopedia of Translated Prophetic Hadiths. Holds no
 * state, needs no key.
 *
 * Shapes mirror the live API, which differs from alquran.cloud in ways that
 * break a parser written for the other one:
 * - there is no `{code, data}` envelope; the body is the payload itself;
 * - ids and most counts are strings (`"id":"66530"`, `"hadeeths_count":"471"`),
 *   though `total_items` is a number;
 * - a hadith missing in the asked language is a 404 with an empty body, not an
 *   error object;
 * - asked in Arabic, the plain fields are the Arabic and the `_ar` ones are absent.
 */
class HadeethEncApi(
    private val client: OkHttpClient,
    private val baseUrl: HttpUrl,
) : HadithApi {
    override suspend fun roots(language: String): List<HadithCategory> {
        val body = get("categories/roots/", "language" to language)
            ?: throw HadeethEncException("categories/roots returned 404")
        return parse("roots") {
            body.jsonArray.map {
                val row = it.jsonObject
                HadithCategory(id = row.text("id"), count = row.number("hadeeths_count"))
            }
        }
    }

    override suspend fun entry(language: String, category: String, page: Int): HadithEntry? {
        val body = get(
            "hadeeths/list/",
            "language" to language,
            "category_id" to category,
            "page" to page.toString(),
            "per_page" to "1",
        ) ?: throw HadeethEncException("hadeeths/list returned 404")
        return parse("list") {
            val row = body.jsonObject.getValue("data").jsonArray.firstOrNull()?.jsonObject
                ?: return@parse null
            HadithEntry(id = row.text("id"), languages = row.texts("translations"))
        }
    }

    override suspend fun hadith(id: String, language: String): Hadith? {
        val body = get("hadeeths/one/", "language" to language, "id" to id) ?: return null
        return parse("hadith $id") {
            val row = body.jsonObject
            val arabicAsked = language == ARABIC
            Hadith(
                id = row.text("id"),
                language = language,
                languages = row.texts("translations"),
                arabic = row.text(if (arabicAsked) "hadeeth" else "hadeeth_ar"),
                translation = if (arabicAsked) null else row.text("hadeeth"),
                attribution = row.text("attribution"),
                grade = row.text("grade"),
                explanation = row.text("explanation"),
                hints = row.texts("hints"),
            )
        }
    }

    /** The parsed body, or null for a 404. Anything else that is not a 200 throws. */
    private suspend fun get(path: String, vararg query: Pair<String, String>): JsonElement? =
        withContext(Dispatchers.IO) {
            val url = baseUrl.resolve(path)?.newBuilder()?.apply {
                for ((key, value) in query) addQueryParameter(key, value)
            }?.build() ?: throw HadeethEncException("bad path $path")

            val bytes = try {
                client.newCall(Request.Builder().url(url).build()).execute().use { response ->
                    if (response.code == 404) return@withContext null
                    if (response.code != 200) throw HadeethEncException("GET $path returned ${response.code}")
                    response.body.bytes()
                }
            } catch (e: IOException) {
                // OkHttp's call timeout surfaces as an InterruptedIOException.
                throw HadeethEncException("GET $path failed: ${e.message}", e)
            }

            try {
                Json.parseToJsonElement(bytes.toString(Charsets.UTF_8))
            } catch (e: Exception) {
                throw HadeethEncException("GET $path returned a body that is not JSON", e)
            }
        }

    /** Any shape surprise in a 200 response is a malformed body, not a crash. */
    private inline fun <T> parse(what: String, block: () -> T): T =
        try {
            block()
        } catch (e: HadeethEncException) {
            throw e
        } catch (e: Exception) {
            throw HadeethEncException("$what: malformed body (${e.message})", e)
        }

    companion object {
        const val BASE_URL = "https://hadeethenc.com/api/v1/"

        /** The draw is made in English: the largest set after Arabic, and the fallback. */
        const val ENGLISH = "en"
        const val ARABIC = "ar"

        private fun JsonObject.text(key: String): String =
            (getValue(key) as? JsonPrimitive)?.takeIf { it.isString }?.content
                ?: throw IllegalArgumentException("$key is not a string")

        /** A count, sent as a string or as a number depending on the field. */
        private fun JsonObject.number(key: String): Int =
            (getValue(key) as JsonPrimitive).content.toInt()

        private fun JsonObject.texts(key: String): List<String> =
            (getValue(key) as JsonArray).map {
                (it as? JsonPrimitive)?.takeIf { p -> p.isString }?.content
                    ?: throw IllegalArgumentException("$key holds a non-string")
            }
    }
}
