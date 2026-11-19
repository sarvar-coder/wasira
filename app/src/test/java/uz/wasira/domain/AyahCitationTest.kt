package uz.wasira.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AyahCitationTest {
    /** 2:255, Ayat al-Kursi, as the API returns it. */
    private val arabic =
        "ٱللَّهُ لَآ إِلَٰهَ " +
            "إِلَّا هُوَ"

    @Test fun `reads Arabic, translation, then the reference`() {
        assertEquals(
            "$arabic\n\nAllah - there is no deity except Him\n\n— Al-Baqara 2:255",
            ayahCitation(
                arabic = arabic,
                translation = "Allah - there is no deity except Him",
                surahName = "Al-Baqara",
                surah = 2,
                numberInSurah = 255,
            ),
        )
    }

    @Test fun `leaves the Arabic byte for byte`() {
        val text = ayahCitation(arabic = arabic, surahName = "Al-Baqara", surah = 2, numberInSurah = 255)
        assertTrue(text.startsWith(arabic))
    }

    @Test fun `omits the translation rather than leaving a blank line`() {
        for (empty in listOf(null, "")) {
            val text = ayahCitation(
                arabic = arabic,
                translation = empty,
                surahName = "Al-Baqara",
                surah = 2,
                numberInSurah = 255,
            )
            assertEquals("$arabic\n\n— Al-Baqara 2:255", text)
        }
    }

    @Test fun `the reference is surah-ayah, not the global number`() {
        // 2:255 is global ayah 262; the citation people recognise is 2:255.
        assertEquals("2:255", ayahReference(2, 255))
        assertEquals("1:1", ayahReference(1, 1))
        assertEquals("114:6", ayahReference(114, 6))
    }
}
