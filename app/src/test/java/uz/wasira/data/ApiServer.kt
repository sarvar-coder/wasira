package uz.wasira.data

import java.util.concurrent.TimeUnit
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import mockwebserver3.MockResponse
import okhttp3.OkHttpClient
import okio.Buffer

/** Helpers that build responses in the shape the live API sends. */
internal object ApiServer {
    fun client(timeoutMillis: Long = 5_000): OkHttpClient =
        OkHttpClient.Builder().callTimeout(timeoutMillis, TimeUnit.MILLISECONDS).build()

    fun bytes(body: ByteArray, code: Int = 200): MockResponse =
        MockResponse.Builder()
            .code(code)
            .addHeader("content-type", "application/json; charset=utf-8")
            .body(Buffer().write(body))
            .build()

    fun ok(data: JsonElement): MockResponse =
        bytes(
            JsonObject(mapOf("code" to JsonPrimitive(200), "status" to JsonPrimitive("OK"), "data" to data))
                .toString().toByteArray(Charsets.UTF_8),
        )

    /** سُورَةُ البَقَرَةِ */
    const val BAQARAH_AR = "سُورَةُ البَقَرَةِ"

    /**
     * One row of `/ayah/{n}/editions/a,b`: an ayah with its surah and edition
     * inline, which is why nothing else has to be stored to render a citation.
     */
    fun row(
        edition: String,
        text: String,
        numberInSurah: Int = 255,
        sajda: JsonElement = JsonPrimitive(false),
        direction: String? = null,
    ): JsonObject = buildJsonObject {
        put("number", 262)
        put("text", text)
        put("numberInSurah", numberInSurah)
        put("juz", 3)
        put("manzil", 1)
        put("page", 42)
        put("ruku", 35)
        put("hizbQuarter", 20)
        put("sajda", sajda)
        put("surah", buildJsonObject {
            put("number", 2)
            put("name", BAQARAH_AR)
            put("englishName", "Al-Baqara")
            put("englishNameTranslation", "The Cow")
            put("revelationType", "Medinan")
            put("numberOfAyahs", 286)
        })
        put("edition", buildJsonObject {
            put("identifier", edition)
            if (direction != null) put("direction", direction)
        })
    }

    fun rows(vararg rows: JsonObject) = JsonArray(rows.toList())
}
