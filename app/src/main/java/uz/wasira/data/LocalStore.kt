package uz.wasira.data

import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject

/**
 * One JSON object in one file. Writes go through a temporary file and a rename,
 * so a crash mid-write leaves the previous contents. Reads never throw: a missing
 * or corrupt file reads as an empty object.
 *
 * A missing file is the first launch, and a corrupt one is indistinguishable
 * from it as far as the app can act. Blocking IO: callers move it off the main
 * thread.
 */
class LocalStore(val file: File) {
    @Synchronized
    fun read(): JsonObject =
        try {
            Json.parseToJsonElement(file.readText(Charsets.UTF_8)) as? JsonObject ?: EMPTY
        } catch (_: Exception) {
            EMPTY
        }

    @Synchronized
    fun write(value: JsonObject) {
        val part = File("${file.path}.part")
        part.parentFile?.mkdirs()
        part.outputStream().use { out ->
            out.write(value.toString().toByteArray(Charsets.UTF_8))
            out.fd.sync()
        }
        try {
            Files.move(part.toPath(), file.toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
        } catch (_: UnsupportedOperationException) {
            Files.move(part.toPath(), file.toPath(), StandardCopyOption.REPLACE_EXISTING)
        }
    }

    /** Merge [values] over the current contents and write. */
    @Synchronized
    fun update(values: JsonObject) = write(JsonObject(read() + values))

    @Synchronized
    fun clear() {
        if (file.exists()) file.delete()
    }

    private companion object {
        val EMPTY = JsonObject(emptyMap())
    }
}
