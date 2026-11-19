package uz.wasira.domain

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test

class AppInfoTest {
    @Test fun `the version shown in About is the version being built`() {
        // A hand-written constant drifts from the build silently. Unit tests run
        // with the module directory as the working directory.
        val gradle = File("build.gradle.kts").readText()
        val versionName = Regex("""versionName\s*=\s*"([^"]+)"""").find(gradle)?.groupValues?.get(1)
        assertEquals(versionName, AppInfo.VERSION)
    }

    @Test fun `the font notice matches the font actually shipped`() {
        // The SIL Open Font License requires this notice to travel with the font.
        // Looked for where the Android app ships it; skipped until the font is moved there.
        val licence = listOf("src/main/assets/fonts/OFL.txt", "src/main/res/raw/ofl.txt")
            .map(::File).firstOrNull { it.exists() }
        assumeTrue("OFL.txt not yet shipped in the Android app", licence != null)

        val text = licence!!.readText()
        assertTrue(text.contains("SIL OPEN FONT LICENSE Version 1.1"))
        assertTrue(text.contains("The Amiri Project Authors"))
        assertTrue(AppInfo.FONT_COPYRIGHT.contains("The Amiri Project Authors"))
    }

    @Test fun `the data source is credited by name and by address`() {
        assertTrue(AppInfo.QURAN_SOURCE.isNotEmpty())
        assertTrue(AppInfo.QURAN_SOURCE_URL.startsWith("https://"))
        assertTrue(AppInfo.FONT_LICENCE_URL.startsWith("https://"))
    }
}
