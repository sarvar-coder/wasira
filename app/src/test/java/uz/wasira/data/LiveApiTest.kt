package uz.wasira.data

import java.util.concurrent.TimeUnit
import kotlinx.coroutines.test.runTest
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Test
import uz.wasira.Fixtures
import uz.wasira.domain.BISMILLAH_UTHMANI
import uz.wasira.domain.withoutOpeningBismillah
import kotlin.time.Duration.Companion.seconds

/**
 * Against the real alquran.cloud. Off by default so CI never depends on the
 * network; run with `WASIRA_LIVE_API=1 ./gradlew testDebugUnitTest`.
 * Assumptions about this API have shipped bugs before — this is how to check.
 */
class LiveApiTest {
    @Before fun onlyWhenAsked() = assumeTrue(System.getenv("WASIRA_LIVE_API") == "1")

    private val api = AlquranApi(
        OkHttpClient.Builder().callTimeout(60, TimeUnit.SECONDS).build(),
        AlquranApi.BASE_URL.toHttpUrl(),
    )

    @Test fun `2-1 arrives glued and splits to alif lam meem`() = runTest(timeout = 90.seconds) {
        val fetched = api.ayah(8, "en.sahih")
        assertEquals(Fixtures.ayahOne("2"), fetched.ayah.text)
        assertEquals("الٓمٓ", fetched.ayah.withoutOpeningBismillah().text)
        assertEquals("Alif, Lam, Meem.", fetched.translation)
        assertEquals("ltr", fetched.translationDirection)
    }

    @Test fun `27-30 arrives byte-identical to the fixture and is never split`() = runTest(timeout = 90.seconds) {
        val ayah = api.ayah(3189, "en.sahih").ayah
        assertEquals(30, ayah.numberInSurah)
        assertEquals(Fixtures.ayahOne("27:30"), ayah.text)
        assertTrue(ayah.text.contains(BISMILLAH_UTHMANI))
        assertEquals(ayah, ayah.withoutOpeningBismillah())
    }

    @Test fun `95-1 still carries the spurious shadda and still splits`() = runTest(timeout = 90.seconds) {
        val ayah = api.ayah(6099, null).ayah
        assertEquals(Fixtures.ayahOne("95"), ayah.text)
        assertEquals('ّ', ayah.text[1])
        assertTrue(ayah.withoutOpeningBismillah().text.length < ayah.text.length)
    }

    @Test fun `32-15 sajda arrives as an object with its ruling`() = runTest(timeout = 90.seconds) {
        val fetched = api.ayah(3518, "en.sahih")
        assertTrue(fetched.ayah.sajda)
        assertEquals(true, fetched.ayah.sajdaObligatory)
        assertEquals(32, fetched.ayah.surah.number)
    }

    @Test fun `an ordinary ayah has sajda false and no ruling`() = runTest(timeout = 90.seconds) {
        val ayah = api.ayah(262, null).ayah
        assertEquals(false, ayah.sajda)
        assertNull(ayah.sajdaObligatory)
    }

    @Test fun `the translation list is real and directional`() = runTest(timeout = 90.seconds) {
        val editions = api.translations()
        assertTrue(editions.size > 100)
        assertTrue(editions.single { it.identifier == "uz.sodik" }.direction == "ltr")
        assertTrue(editions.filter { it.language == "ur" }.all { it.isRtl })
    }
}
