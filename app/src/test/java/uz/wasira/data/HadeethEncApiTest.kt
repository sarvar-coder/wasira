package uz.wasira.data

import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonPrimitive
import mockwebserver3.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import uz.wasira.Fixtures

/**
 * Against responses captured from the live HadeethEnc API on 2026-11-19
 * (fixtures/hadith_*.json). The shapes are pinned here rather than described in
 * comments: string ids and counts, no envelope, a 404 with an empty body for a
 * missing language, and plain fields that are Arabic when Arabic is asked for.
 */
class HadeethEncApiTest {
    private val server = MockWebServer()

    @Before fun start() = server.start()
    @After fun stop() = server.close()

    private fun api() = HadeethEncApi(ApiServer.client(), server.url("/api/v1/"))

    private fun fixture(name: String) = ApiServer.bytes(Fixtures.bytes(name))

    private suspend fun assertThrowsApi(block: suspend () -> Unit) {
        try {
            block()
            fail("expected HadeethEncException")
        } catch (_: HadeethEncException) {
        }
    }

    @Test fun `roots - ids and counts arrive as strings`() = runTest {
        server.enqueue(fixture("hadith_roots_en.json"))
        val roots = api().roots("en")
        assertEquals(7, roots.size)
        assertEquals(HadithCategory("3", 471), roots[2])
        assertEquals("/api/v1/categories/roots/?language=en", server.takeRequest().target)
    }

    @Test fun `entry - one hadith per page, with the languages it exists in`() = runTest {
        server.enqueue(fixture("hadith_list_en.json"))
        val entry = api().entry("en", "3", 1)!!
        assertEquals("66512", entry.id)
        assertTrue("uz" in entry.languages)
        assertEquals(
            "/api/v1/hadeeths/list/?language=en&category_id=3&page=1&per_page=1",
            server.takeRequest().target,
        )
    }

    @Test fun `entry - past the last page is null`() = runTest {
        server.enqueue(ApiServer.bytes("""{"data":[],"meta":{"current_page":"9999","last_page":471,"total_items":471,"per_page":"1"}}""".toByteArray()))
        assertNull(api().entry("en", "3", 9999))
    }

    @Test fun `hadith in english - arabic from hadeeth_ar, translation from hadeeth, strings untouched`() = runTest {
        server.enqueue(fixture("hadith_66530_en.json"))
        val hadith = api().hadith("66530", "en")!!
        val raw = Fixtures.json("hadith_66530_en.json")

        assertEquals("66530", hadith.id)
        assertEquals("en", hadith.language)
        assertEquals(raw.getValue("hadeeth_ar").jsonPrimitive.content, hadith.arabic)
        assertEquals(raw.getValue("hadeeth").jsonPrimitive.content, hadith.translation)
        assertEquals("Narrated by At-Tirmidhi", hadith.attribution)
        assertEquals("Authentic", hadith.grade)
        assertEquals(raw.getValue("explanation").jsonPrimitive.content, hadith.explanation)
        // Sent with a trailing carriage return, and kept with it: the terms forbid altering the content.
        assertEquals(raw.getValue("hints").jsonArray.map { it.jsonPrimitive.content }, hadith.hints)
        assertTrue(hadith.hints.first().endsWith("\r"))
        assertEquals("/api/v1/hadeeths/one/?language=en&id=66530", server.takeRequest().target)
    }

    @Test fun `hadith in uzbek - cyrillic text, same arabic as in english`() = runTest {
        server.enqueue(fixture("hadith_66530_uz.json"))
        server.enqueue(fixture("hadith_66530_en.json"))
        val uz = api().hadith("66530", "uz")!!
        val en = api().hadith("66530", "en")!!
        assertTrue(uz.translation!!.startsWith("Муоз ибн Жабал"))
        assertEquals(en.arabic, uz.arabic)
    }

    @Test fun `hadith in arabic - the plain fields are the arabic and there is no translation`() = runTest {
        server.enqueue(fixture("hadith_66530_ar.json"))
        server.enqueue(fixture("hadith_66530_en.json"))
        val ar = api().hadith("66530", "ar")!!
        val en = api().hadith("66530", "en")!!
        assertEquals(en.arabic, ar.arabic)
        assertNull(ar.translation)
        val raw = Fixtures.json("hadith_66530_en.json")
        assertEquals(raw.getValue("explanation_ar").jsonPrimitive.content, ar.explanation)
    }

    @Test fun `missing in that language - 404 with an empty body is null`() = runTest {
        server.enqueue(ApiServer.bytes("\"\"".toByteArray(), code = 404))
        assertNull(api().hadith("3339", "uz"))
    }

    @Test fun `server error - throws`() = runTest {
        server.enqueue(ApiServer.bytes("oops".toByteArray(), code = 500))
        assertThrowsApi { api().hadith("1", "en") }
    }

    @Test fun `not json - throws`() = runTest {
        server.enqueue(ApiServer.bytes("<html>".toByteArray()))
        assertThrowsApi { api().roots("en") }
    }

    @Test fun `missing field - throws rather than crashing`() = runTest {
        server.enqueue(ApiServer.bytes("""{"id":"1","hadeeth":"x"}""".toByteArray()))
        assertThrowsApi { api().hadith("1", "en") }
    }
}
