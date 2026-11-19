package uz.wasira.data

import java.util.concurrent.TimeUnit
import kotlinx.coroutines.test.runTest
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Test
import kotlin.time.Duration.Companion.seconds

/**
 * Against the real HadeethEnc. Off by default so CI never depends on the
 * network; run with `WASIRA_LIVE_API=1 ./gradlew testDebugUnitTest`.
 */
class LiveHadithApiTest {
    @Before fun onlyWhenAsked() = assumeTrue(System.getenv("WASIRA_LIVE_API") == "1")

    private val api = HadeethEncApi(
        OkHttpClient.Builder().callTimeout(60, TimeUnit.SECONDS).build(),
        HadeethEncApi.BASE_URL.toHttpUrl(),
    )

    @Test fun `the english listing is large enough for years without a repeat`() = runTest(timeout = 120.seconds) {
        val roots = api.roots("en")
        assertEquals(7, roots.size)
        assertTrue(roots.sumOf { it.count } > 2_000)
    }

    @Test fun `a listed hadith fetches in english with arabic alongside`() = runTest(timeout = 120.seconds) {
        val entry = api.entry("en", api.roots("en").first().id, 1)!!
        val hadith = api.hadith(entry.id, "en")!!
        assertTrue(hadith.arabic.isNotEmpty())
        assertTrue(hadith.explanation.isNotEmpty())
    }

    @Test fun `3339 has no uzbek copy - a 404, read as null`() = runTest(timeout = 120.seconds) {
        assertNull(api.hadith("3339", "uz"))
        assertNotNull(api.hadith("3339", "en"))
    }

    @Test fun `arabic asked - the arabic matches the english response's`() = runTest(timeout = 120.seconds) {
        assertEquals(api.hadith("66530", "en")!!.arabic, api.hadith("66530", "ar")!!.arabic)
    }
}
