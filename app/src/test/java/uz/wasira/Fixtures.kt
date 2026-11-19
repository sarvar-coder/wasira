package uz.wasira

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/** Real responses captured from alquran.cloud, in src/test/resources/fixtures. */
object Fixtures {
    fun bytes(name: String): ByteArray =
        requireNotNull(Fixtures::class.java.classLoader!!.getResourceAsStream("fixtures/$name")) {
            "missing fixture $name"
        }.use { it.readBytes() }

    fun text(name: String): String = bytes(name).toString(Charsets.UTF_8)

    fun json(name: String): JsonObject = Json.parseToJsonElement(text(name)).jsonObject

    /** Ayah 1 of every surah in `quran-uthmani`, as the API sends it, plus 27:30. */
    private val ayahOnes: JsonObject by lazy { json("ayah_ones_uthmani.json") }

    fun ayahOne(key: String): String = ayahOnes.getValue(key).jsonPrimitive.content
}
