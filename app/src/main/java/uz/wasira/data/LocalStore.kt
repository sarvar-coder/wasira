package uz.wasira.data

import java.io.File
import kotlinx.serialization.json.JsonObject

/**
 * One JSON object in one file. Writes go through a temporary file and a rename,
 * so a crash mid-write leaves the previous contents. Reads never throw: a missing
 * or corrupt file reads as an empty object.
 */
class LocalStore(val file: File) {
    fun read(): JsonObject = TODO("Agent A")
    fun write(value: JsonObject): Unit = TODO("Agent A")
    /** Merge [values] over the current contents and write. */
    fun update(values: JsonObject): Unit = TODO("Agent A")
    fun clear(): Unit = TODO("Agent A")
}
