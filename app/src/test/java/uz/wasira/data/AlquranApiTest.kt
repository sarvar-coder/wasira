package uz.wasira.data

import java.util.concurrent.TimeUnit
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import mockwebserver3.MockResponse
import mockwebserver3.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import uz.wasira.Fixtures
import uz.wasira.data.ApiServer.ok
import uz.wasira.data.ApiServer.row
import uz.wasira.data.ApiServer.rows

/**
 * Response shapes mirror the live API, including the quirks that break naive
 * parsing: `sajda` is `false` or an object, and Arabic text must survive as UTF-8.
 */
class AlquranApiTest {
    private val server = MockWebServer()

    @Before fun start() = server.start()
    @After fun stop() = server.close()

    private fun api(timeoutMillis: Long = 5_000) = AlquranApi(ApiServer.client(timeoutMillis), server.url("/v1/"))

    private suspend fun assertThrowsApi(block: suspend () -> Unit) {
        try {
            block()
            fail("expected AlquranApiException")
        } catch (_: AlquranApiException) {
        }
    }

    /** ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ */
    private val kursi =
        "ٱللَّهُ لَآ إِلَٰهَ " +
            "إِلَّا هُوَ"

    /** نَصٌّ */
    private val nass = "نَصٌّ"

    @Test fun `an ayah arrives with its surah, and the Arabic survives UTF-8`() = runTest {
        server.enqueue(ok(rows(
            row("quran-uthmani", kursi),
            row("en.sahih", "Allah - there is no deity except Him", direction = "ltr"),
        )))

        val result = api().ayah(262, "en.sahih")

        assertEquals(kursi, result.ayah.text)
        assertEquals("Allah - there is no deity except Him", result.translation)
        assertEquals("ltr", result.translationDirection)
        assertEquals("Al-Baqara", result.ayah.surah.nameEn)
        assertEquals(ApiServer.BAQARAH_AR, result.ayah.surah.nameAr)
        assertEquals(2, result.ayah.surah.number)
        assertEquals(286, result.ayah.surah.ayahCount)
        assertEquals(255, result.ayah.numberInSurah)
        assertEquals(262, result.ayah.number)
    }

    @Test fun `asks for both editions in one request`() = runTest {
        server.enqueue(ok(rows(row("quran-uthmani", nass), row("uz.sodik", "matn"))))

        api().ayah(262, "uz.sodik")

        assertEquals("/v1/ayah/262/editions/quran-uthmani,uz.sodik", server.takeRequest().url.encodedPath)
    }

    @Test fun `reading Arabic only asks for one edition and carries no translation`() = runTest {
        server.enqueue(ok(rows(row("quran-uthmani", nass))))
        server.enqueue(ok(rows(row("quran-uthmani", nass))))

        val result = api().ayah(2, null)
        api().ayah(2, "quran-uthmani")

        assertEquals("/v1/ayah/2/editions/quran-uthmani", server.takeRequest().url.encodedPath)
        assertEquals("/v1/ayah/2/editions/quran-uthmani", server.takeRequest().url.encodedPath)
        assertNull(result.translation)
        assertNull(result.translationDirection)
    }

    @Test fun `an ayah missing its Arabic throws rather than rendering blank`() = runTest {
        server.enqueue(ok(rows(row("en.sahih", "only a translation"))))
        assertThrowsApi { api().ayah(262, "en.sahih") }
    }

    @Test fun `sajda false stays false, sajda object becomes true with its ruling`() = runTest {
        server.enqueue(ok(rows(row("quran-uthmani", nass))))
        server.enqueue(ok(rows(row("quran-uthmani", nass, sajda = buildJsonObject {
            put("id", 10)
            put("recommended", false)
            put("obligatory", true)
        }))))

        val plain = api().ayah(262, null).ayah
        assertFalse(plain.sajda)
        assertNull(plain.sajdaObligatory)

        val marked = api().ayah(262, null).ayah
        assertTrue(marked.sajda)
        assertEquals(true, marked.sajdaObligatory)
    }

    @Test fun `editions carry direction, which drives translation text direction`() = runTest {
        server.enqueue(ok(JsonArray(listOf(buildJsonObject {
            put("identifier", "ur.jalandhry")
            put("language", "ur")
            put("name", "اردو")
            put("englishName", "Jalandhry")
            put("format", "text")
            put("type", "translation")
            put("direction", "rtl")
        }))))

        val edition = api().translations().single()

        assertEquals("rtl", edition.direction)
        assertTrue(edition.isRtl)
    }

    @Test fun `non-200 status throws`() = runTest {
        server.enqueue(MockResponse.Builder().code(503).body("nope").build())
        assertThrowsApi { api().translations() }

        // The status alone decides: a well-formed body behind a 503 is still refused.
        server.enqueue(ok(rows(row("quran-uthmani", nass))).newBuilder().code(503).build())
        assertThrowsApi { api().ayah(262, null) }
    }

    @Test fun `200 status carrying a non-200 body code throws`() = runTest {
        server.enqueue(ApiServer.bytes("""{"code":404,"data":"Invalid edition."}""".toByteArray()))
        assertThrowsApi { api().ayah(1, "xx.nope") }

        // The code alone decides: data that would otherwise parse is still refused.
        val parseable = JsonObject(mapOf("code" to JsonPrimitive(500), "data" to rows(row("quran-uthmani", nass))))
        server.enqueue(ApiServer.bytes(parseable.toString().toByteArray()))
        assertThrowsApi { api().ayah(262, null) }
    }

    @Test fun `a body that is not a JSON object throws`() = runTest {
        server.enqueue(ApiServer.bytes("[1,2]".toByteArray()))
        server.enqueue(ApiServer.bytes("<html>".toByteArray()))
        assertThrowsApi { api().translations() }
        assertThrowsApi { api().translations() }
    }

    @Test fun `requests hit the documented paths`() = runTest {
        server.enqueue(ok(JsonArray(emptyList())))

        api().translations()

        val url = server.takeRequest().url
        assertEquals("/v1/edition", url.encodedPath)
        assertEquals("text", url.queryParameter("format"))
        assertEquals("translation", url.queryParameter("type"))
    }

    @Test fun `a hanging response times out instead of waiting forever`() = runTest {
        server.enqueue(ok(JsonArray(emptyList())).newBuilder().headersDelay(5, TimeUnit.SECONDS).build())
        assertThrowsApi { api(timeoutMillis = 100).translations() }
    }

    @Test fun `an unreachable server throws the API exception`() = runTest {
        val url = server.url("/v1/")
        server.close()
        assertThrowsApi { AlquranApi(ApiServer.client(), url).translations() }
    }

    // -- against real captured API responses

    @Test fun `a real ayah 1 still arrives with the Bismillah glued on`() = runTest {
        // Splitting it is DailyRepository's job; the API must hand it over untouched.
        val raw = Fixtures.ayahOne("2")
        server.enqueue(ok(rows(row("quran-uthmani", raw, numberInSurah = 1))))

        val result = api().ayah(8, null)

        assertEquals(raw, result.ayah.text)
        assertTrue(result.ayah.text.startsWith("بِسْمِ"))
        assertTrue(result.ayah.text.endsWith("الٓمٓ"))
    }

    @Test fun `the BOM on 1-1 is passed through, not stripped here`() = runTest {
        val raw = Fixtures.ayahOne("1")
        assertTrue(raw.startsWith("﻿"))
        server.enqueue(ok(rows(row("quran-uthmani", raw, numberInSurah = 1))))

        assertEquals(raw, api().ayah(1, null).ayah.text)
    }

    @Test fun `a single unwrapped ayah response parses too`() = runTest {
        // `/ayah/{n}/{edition}` answers with an object rather than a list.
        server.enqueue(ApiServer.bytes(Fixtures.bytes("ayah_32_15_sajda.json")))

        val result = api().ayah(3518, null)

        assertTrue(result.ayah.sajda)
        assertEquals(true, result.ayah.sajdaObligatory)
        assertEquals(32, result.ayah.surah.number)
        assertEquals(15, result.ayah.numberInSurah)
        assertEquals(30, result.ayah.surah.ayahCount)
    }

    @Test fun `real Urdu editions are marked rtl`() = runTest {
        server.enqueue(ApiServer.bytes(Fixtures.bytes("editions_ur.json")))

        val editions = api().translations()

        assertTrue(editions.isNotEmpty())
        assertTrue(editions.all { it.direction == "rtl" })
    }

    @Test fun `every real translation edition parses`() = runTest {
        server.enqueue(ApiServer.bytes(Fixtures.bytes("editions_all.json")))

        val editions = api().translations()

        assertTrue(editions.size > 100)
        assertTrue(editions.any { it.identifier == "en.sahih" && it.direction == "ltr" })
        assertTrue(editions.any { it.identifier == "uz.sodik" })
    }
}
