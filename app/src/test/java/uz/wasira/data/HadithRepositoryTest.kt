package uz.wasira.data

import java.io.File
import java.time.LocalDate
import kotlin.random.Random
import kotlinx.coroutines.test.runTest
import mockwebserver3.Dispatcher
import mockwebserver3.MockResponse
import mockwebserver3.MockWebServer
import mockwebserver3.RecordedRequest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import uz.wasira.Fixtures

/**
 * The hadith repository against a real [HadeethEncApi] over HTTP to a local
 * server answering with captured live responses, with a real file on disk.
 */
class HadithRepositoryTest {
    @get:Rule val tmp = TemporaryFolder()

    private val server = MockWebServer()
    private val paths = mutableListOf<String>()

    /** Languages the fake has hadith 66530 in. The live one has dozens; uz is the one that matters. */
    private var languages = setOf("ar", "en", "uz")
    private var fail = false
    private var date = LocalDate.of(2026, 11, 19)

    private lateinit var store: LocalStore

    @Before fun start() {
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse {
                val url = request.url
                paths += url.encodedPath + "?" + url.encodedQuery
                if (fail) return ApiServer.bytes("oops".toByteArray(), code = 500)
                return when (url.encodedPath) {
                    "/api/v1/categories/roots/" -> ApiServer.bytes(Fixtures.bytes("hadith_roots_en.json"))
                    // Always answers 66512's listing, which names uz among its languages.
                    "/api/v1/hadeeths/list/" -> ApiServer.bytes(Fixtures.bytes("hadith_list_en.json"))
                    "/api/v1/hadeeths/one/" -> {
                        val language = url.queryParameter("language")!!
                        if (language in languages) {
                            ApiServer.bytes(Fixtures.bytes("hadith_66530_$language.json"))
                        } else {
                            ApiServer.bytes("\"\"".toByteArray(), code = 404)
                        }
                    }
                    else -> ApiServer.bytes(ByteArray(0), code = 404)
                }
            }
        }
        server.start()
        store = LocalStore(File(tmp.root, "hadith.json"))
    }

    @After fun stop() = server.close()

    private fun repo(random: Random = Random(7)) = HadithRepository(
        HadeethEncApi(ApiServer.client(), server.url("/api/v1/")),
        store,
        today = { date },
        random = random,
    )

    private fun fetches() = paths.filter { it.startsWith("/api/v1/hadeeths/one/") }

    @Test fun `first draw - roots, one listing page, then the hadith in the asked language`() = runTest {
        val daily = repo().today("uz")
        assertEquals("2026-11-19", daily.date)
        assertEquals("uz", daily.hadith.language)
        assertEquals(3, paths.size)
        assertTrue(paths[0].startsWith("/api/v1/categories/roots/?language=en"))
        assertTrue(paths[1].startsWith("/api/v1/hadeeths/list/?language=en&category_id="))
        assertTrue(paths[1].endsWith("&per_page=1"))
        assertEquals("/api/v1/hadeeths/one/?language=uz&id=66512", paths[2])
    }

    @Test fun `same day - read from disk, no request`() = runTest {
        val first = repo().today("uz")
        paths.clear()
        assertEquals(first, repo().today("uz"))
        assertTrue(paths.isEmpty())
    }

    @Test fun `not in uzbek - english stands in`() = runTest {
        languages = setOf("ar", "en")
        val daily = repo().today("uz")
        assertEquals("en", daily.hadith.language)
        assertTrue(daily.hadith.translation!!.isNotEmpty())
    }

    @Test fun `listed in uzbek but the fetch 404s - english stands in`() = runTest {
        // The listing's language list and the hadith endpoint can disagree.
        languages = setOf("en")
        assertEquals("en", repo().today("uz").hadith.language)
        assertEquals(
            listOf("/api/v1/hadeeths/one/?language=uz&id=66512", "/api/v1/hadeeths/one/?language=en&id=66512"),
            fetches(),
        )
    }

    @Test fun `a language the hadith is not listed in - asked in english straight away`() = runTest {
        // The captured listing names 69 languages, the app's four among them, so
        // an unlisted one has to be invented to reach this branch.
        assertEquals("en", repo().today("xx").hadith.language)
        assertEquals(listOf("/api/v1/hadeeths/one/?language=en&id=66512"), fetches())
    }

    @Test fun `ui language changed the same day - the same hadith, refetched in the new language`() = runTest {
        val uz = repo().today("uz")
        paths.clear()
        val ar = repo().today("ar")
        assertEquals("ar", ar.hadith.language)
        assertEquals(listOf("/api/v1/hadeeths/one/?language=ar&id=${uz.hadith.id}"), paths)
    }

    @Test fun `english stood in for uzbek - the next launch does not ask for uzbek again`() = runTest {
        languages = setOf("ar", "en")
        repo().today("uz")
        paths.clear()
        assertEquals("en", repo().today("uz").hadith.language)
        assertTrue(paths.isEmpty())
    }

    @Test fun `new day - yesterday's hadith is dropped and a new one drawn`() = runTest {
        repo().today("en")
        date = date.plusDays(1)
        paths.clear()
        val next = repo().today("en")
        assertEquals("2026-11-20", next.date)
        assertEquals(3, paths.size)
    }

    @Test fun `failure on a new day - throws, and yesterday's is gone`() = runTest {
        repo().today("en")
        date = date.plusDays(1)
        fail = true
        try {
            repo().today("en")
            fail("expected HadeethEncException")
        } catch (_: HadeethEncException) {
        }
        assertFalse(store.file.exists())
    }

    @Test fun `every string survives the disk round trip byte for byte`() = runTest {
        val fetched = repo().today("uz")
        val read = HadithRepository.fromJson(store.read())
        assertEquals(fetched, read)
        assertTrue(read.hadith.arabic.toByteArray().contentEquals(fetched.hadith.arabic.toByteArray()))
    }

    @Test fun `corrupt file - drawn again`() = runTest {
        store.file.writeText("{not json")
        assertEquals("2026-11-19", repo().today("en").date)
    }

    @Test fun `the draw reaches every category, weighted by size`() = runTest {
        val seen = mutableSetOf<String>()
        repeat(400) { i ->
            store.clear()
            paths.clear()
            repo(Random(i)).today("en")
            seen += Regex("category_id=(\\d+)").find(paths[1])!!.groupValues[1]
        }
        assertEquals(setOf("1", "2", "3", "4", "5", "6", "7"), seen)
    }

    @Test fun `shown in - the asked language when present, english otherwise`() {
        assertEquals("uz", HadithRepository.shownIn("uz", listOf("en", "uz")))
        assertEquals("en", HadithRepository.shownIn("uz", listOf("en", "ru")))
    }
}
