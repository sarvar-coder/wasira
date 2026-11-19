package uz.wasira.data

import java.io.File
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class LocalStoreTest {
    @get:Rule val tmp = TemporaryFolder()

    private val empty = JsonObject(emptyMap())
    private fun obj(vararg pairs: Pair<String, Any>) =
        JsonObject(pairs.associate { (k, v) -> k to if (v is Int) JsonPrimitive(v) else JsonPrimitive(v.toString()) })

    @Test fun `a missing file reads as empty`() {
        assertEquals(empty, LocalStore(File(tmp.root, "none.json")).read())
    }

    @Test fun `corrupt or non-object contents read as empty`() {
        val file = File(tmp.root, "x.json")
        for (contents in listOf("{ nope", "[1,2]", "42", "", "\u0000\u0001")) {
            file.writeText(contents)
            assertEquals(contents, empty, LocalStore(file).read())
        }
    }

    @Test fun `write then read round-trips, Arabic included, and leaves no temp file`() {
        val store = LocalStore(File(tmp.root, "nested/dir/a.json"))
        val value = obj("arabic" to "﻿بِسْمِ", "n" to 3)

        store.write(value)

        assertEquals(value, LocalStore(store.file).read())
        assertFalse(File(store.file.path + ".part").exists())
    }

    @Test fun `update merges over current contents`() {
        val store = LocalStore(File(tmp.root, "a.json"))
        store.write(obj("a" to 1, "b" to 2))

        store.update(obj("b" to 3, "c" to 4))

        assertEquals(obj("a" to 1, "b" to 3, "c" to 4), store.read())
    }

    @Test fun `clear deletes, and clearing nothing is fine`() {
        val store = LocalStore(File(tmp.root, "a.json"))
        store.clear()
        store.write(obj("a" to 1))
        store.clear()
        assertFalse(store.file.exists())
        assertEquals(empty, store.read())
    }
}
