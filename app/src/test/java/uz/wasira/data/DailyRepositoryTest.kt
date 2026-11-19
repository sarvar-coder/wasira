package uz.wasira.data

import java.io.File
import java.time.LocalDate
import java.util.concurrent.atomic.AtomicInteger
import kotlin.random.Random
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonPrimitive
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
import uz.wasira.data.ApiServer.ok
import uz.wasira.data.ApiServer.row
import uz.wasira.data.ApiServer.rows
import uz.wasira.domain.BISMILLAH_UTHMANI
import uz.wasira.domain.dayKey

/**
 * The daily repository against a real [AlquranApi] over HTTP to a local server
 * that answers in the live response shape, with real files on disk.
 */
class DailyRepositoryTest {
    @get:Rule val tmp = TemporaryFolder()

    private val server = MockWebServer()
    private val requests = AtomicInteger()
    private val drawn = mutableListOf<Int>()

    /** What the fake answers with. The real API answers for whatever n was asked; this always answers 2:255. */
    private var arabic = "نَصٌّ"
    private var numberInSurah = 255
    private var fail = false

    private lateinit var root: File
    private lateinit var dailyStore: LocalStore
    private lateinit var settingsStore: LocalStore
    private lateinit var settings: SettingsRepository
    private var date: LocalDate = LocalDate.of(2026, 11, 19)

    @Before fun setUp() {
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse {
                requests.incrementAndGet()
                synchronized(drawn) { drawn += request.url.pathSegments[2].toInt() }
                if (fail) return MockResponse.Builder().code(503).build()
                val translation = request.url.pathSegments[4].split(",").getOrNull(1)
                return ok(rows(
                    row("quran-uthmani", arabic, numberInSurah = numberInSurah, direction = "rtl"),
                    row(translation ?: "none", "Allah - there is no deity except Him", direction = "ltr"),
                ))
            }
        }
        server.start()
        root = tmp.root
        dailyStore = LocalStore(File(root, "daily.json"))
        settingsStore = LocalStore(File(root, "settings.json"))
        settings = SettingsRepository(settingsStore)
    }

    @After fun tearDown() = server.close()

    private fun repo(random: Random = Random.Default) = DailyRepository(
        api = AlquranApi(ApiServer.client(), server.url("/v1/")),
        store = dailyStore,
        settings = settings,
        today = { date },
        random = random,
    )

    @Test fun `is fetched once and read from disk after that`() = runTest {
        settings.setTranslation("en.sahih", "Saheeh International")
        val daily = repo()
        val first = daily.today()

        assertEquals(1, requests.get())
        assertEquals("Al-Baqara", first.ayah.surah.nameEn)
        assertEquals(255, first.ayah.numberInSurah)
        assertEquals("Allah - there is no deity except Him", first.translation)
        assertEquals("ltr", first.translationDirection)
        assertEquals("en.sahih", first.edition)
        assertEquals("2026-11-19", first.date)

        val again = daily.today()
        assertEquals("today is already on disk", 1, requests.get())
        assertEquals(first, again)

        // And from a fresh repository, as after a relaunch.
        assertEquals(first, repo().today())
        assertEquals(1, requests.get())
    }

    @Test fun `is erased and drawn again when the day rolls over`() = runTest {
        settings.setTranslation("en.sahih", null)
        val daily = repo()
        daily.today()
        assertEquals(dayKey(date), dailyStore.read().getValue("date").jsonPrimitive.content)

        date = date.plusDays(1)
        daily.today()

        assertEquals("tomorrow is a different ayah", 2, requests.get())
        assertEquals("2026-11-20", dailyStore.read().getValue("date").jsonPrimitive.content)
    }

    @Test fun `holds exactly one day, never a history`() = runTest {
        settings.setTranslation("en.sahih", null)
        val daily = repo()
        val start = date
        for (d in 0L until 4L) {
            date = start.plusDays(d)
            daily.today()
        }

        assertEquals(dayKey(start.plusDays(3)), dailyStore.read().getValue("date").jsonPrimitive.content)
        val dailyFiles = root.listFiles()!!.filter { it.name.startsWith("daily") }
        assertEquals(listOf("daily.json"), dailyFiles.map { it.name })
    }

    @Test fun `is refetched when the translation changes under it`() = runTest {
        settings.setTranslation("en.sahih", null)
        val daily = repo()
        daily.today()
        settings.setTranslation("uz.sodik", null)
        val after = daily.today()

        assertEquals("a cached ayah carries the translation it was fetched with", 2, requests.get())
        assertEquals("uz.sodik", after.edition)
    }

    @Test fun `no translation is a cache key too`() = runTest {
        val daily = repo()
        daily.today()
        daily.today()
        assertEquals(1, requests.get())
        assertTrue(dailyStore.read().containsKey("edition"))

        settings.setTranslation("en.sahih", null)
        daily.today()
        assertEquals(2, requests.get())
    }

    @Test fun `loses the Bismillah glued onto ayah 1`() = runTest {
        // 2:1 exactly as the live API sends it.
        arabic = Fixtures.ayahOne("2")
        numberInSurah = 1
        settings.setTranslation("en.sahih", null)

        val today = repo().today()

        assertEquals("الٓمٓ", today.ayah.text)
        assertEquals("الٓمٓ", dailyStore.read().getValue("arabic").jsonPrimitive.content)
    }

    @Test fun `27-30 is stored byte-identical to the API`() = runTest {
        arabic = Fixtures.ayahOne("27:30")
        numberInSurah = 30

        assertEquals(arabic, repo().today().ayah.text)
        assertEquals(arabic, repo().today().ayah.text) // through the file as well
        assertTrue(arabic.contains(BISMILLAH_UTHMANI))
    }

    @Test fun `draws inside the Quran`() = runTest {
        val daily = repo()
        repeat(200) {
            dailyStore.clear()
            daily.today()
        }
        assertEquals(200, requests.get())
        assertTrue(drawn.toString(), drawn.all { it in 1..6236 })
    }

    @Test fun `the draw reaches both ends of the Quran`() = runTest {
        val bounds = mutableListOf<Pair<Int, Int>>()
        val edges = object : Random() {
            var call = 0
            override fun nextBits(bitCount: Int) = 0
            override fun nextInt(from: Int, until: Int): Int {
                bounds += from to until
                return if (call++ == 0) from else until - 1
            }
        }
        val daily = repo(edges)
        daily.today()
        dailyStore.clear()
        daily.today()

        assertEquals(listOf(1 to 6237, 1 to 6237), bounds)
        assertEquals(listOf(1, 6236), drawn)
    }

    @Test fun `a failed fetch leaves nothing behind to show tomorrow`() = runTest {
        settings.setTranslation("en.sahih", null)
        repo().today()
        assertTrue(dailyStore.file.exists())

        fail = true
        date = date.plusDays(1)
        try {
            repo().today()
            fail("expected AlquranApiException")
        } catch (_: AlquranApiException) {
        }

        assertEquals(JsonObject(emptyMap()), dailyStore.read())
        assertFalse(dailyStore.file.exists())
    }

    @Test fun `a corrupt daily file is a first launch, not a crash`() = runTest {
        dailyStore.file.writeText("{ this is not json")
        repo().today()
        assertEquals(1, requests.get())
    }

    @Test fun `today's entry with a broken field is fetched again rather than crashing`() = runTest {
        repo().today()
        dailyStore.update(JsonObject(mapOf("number" to JsonPrimitive("not a number"))))

        repo().today()

        assertEquals(2, requests.get())
    }

    @Test fun `daily json carries exactly the documented keys`() = runTest {
        settings.setTranslation("en.sahih", null)
        repo().today()

        assertEquals(
            setOf(
                "date", "edition", "number", "numberInSurah", "sajda", "sajdaObligatory", "arabic",
                "translation", "translationDirection", "surahNumber", "surahNameAr", "surahNameEn",
                "surahNameEnTranslation", "surahRevelationType", "surahAyahCount",
            ),
            dailyStore.read().keys,
        )
    }
}
