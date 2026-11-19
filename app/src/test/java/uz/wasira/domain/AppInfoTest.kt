package uz.wasira.domain

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
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
        assertTrue(File("src/main/res/font/amiri_quran.ttf").exists())
        assertTrue(File("src/main/res/font/amiri_regular.ttf").exists())
        assertTrue(File("src/main/res/font/amiri_bold.ttf").exists())
        val text = File("src/main/assets/OFL.txt").readText()
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
