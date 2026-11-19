package uz.wasira.ui.daily

import org.junit.Assert.assertEquals
import org.junit.Test
import uz.wasira.ui.fixture

class CitationTest {
    private val daily = fixture("golden_2_255")

    @Test fun `arabic, translation, then the citation with an em dash`() {
        val text = ayahCitation(daily.ayah.text, daily.translation, "Al-Baqara", 2, 255)
        assertEquals("${daily.ayah.text}\n\n${daily.translation}\n\n— Al-Baqara 2:255", text)
    }

    @Test fun `an empty translation is left out`() {
        assertEquals("ع\n\n— Al-Faatiha 1:1", ayahCitation("ع", "", "Al-Faatiha", 1, 1))
        assertEquals("ع\n\n— Al-Faatiha 1:1", ayahCitation("ع", null, "Al-Faatiha", 1, 1))
    }

    @Test fun `the arabic leaves byte for byte`() {
        val text = ayahCitation(daily.ayah.text, null, "Al-Baqara", 2, 255)
        assertEquals(daily.ayah.text, text.substringBefore("\n\n—"))
    }
}
