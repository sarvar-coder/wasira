package uz.wasira.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.wasira.Fixtures

/**
 * The highest-stakes test in the app. Every case runs against real captured
 * alquran.cloud text, not hand-written strings, because the whole point is that
 * the split matches what the API actually sends.
 */
class BismillahTest {
    private fun ayahOne(surah: Int) = Fixtures.ayahOne("$surah")

    private fun split(surah: Int, numberInSurah: Int = 1, text: String? = null) =
        splitOpeningBismillah(surah = surah, numberInSurah = numberInSurah, text = text ?: ayahOne(surah))

    /** The malformed spelling in 95 and 97 is one code unit longer: a shadda on the beh. */
    private val bismillahWithShaddaLength = BISMILLAH_UTHMANI.length + 1

    // -- the constant

    @Test fun `the constant matches what the API actually sends`() {
        // 1:1 IS the Bismillah, so it doubles as the reference string. If the API
        // changes its orthography this fails rather than silently disabling every split.
        assertEquals(BISMILLAH_UTHMANI, ayahOne(1).replaceFirst("﻿", ""))
    }

    // -- Al-Fatiha keeps its Bismillah as ayah 1

    @Test fun `Al-Fatiha produces no header`() {
        assertNull(split(1).header)
    }

    @Test fun `Al-Fatiha keeps its full text and loses only the BOM`() {
        assertEquals(BISMILLAH_UTHMANI, split(1).text)
        assertTrue("stripping here would empty Al-Fatiha 1:1", split(1).text.isNotEmpty())
    }

    // -- At-Tawbah has no Bismillah at all

    @Test fun `At-Tawbah produces no header`() {
        assertNull(split(9).header)
    }

    @Test fun `At-Tawbah opening words survive untouched`() {
        assertEquals(ayahOne(9), split(9).text)
        assertFalse(split(9).text.contains(BISMILLAH_UTHMANI))
    }

    // -- every other surah splits

    @Test fun `all 112 others produce a header and a non-empty remainder`() {
        val failures = mutableListOf<String>()
        for (s in 1..114) {
            if (s == 1 || s == 9) continue
            val result = split(s)
            if (result.header != BISMILLAH_UTHMANI) failures += "surah $s: no header"
            if (result.text.isBlank()) failures += "surah $s: empty remainder"
            if (result.text.contains(BISMILLAH_UTHMANI)) failures += "surah $s: Bismillah still in ayah text"
        }
        assertEquals(emptyList<String>(), failures)
    }

    @Test fun `Al-Baqarah 2-1 becomes alif lam meem alone`() {
        assertEquals("الٓمٓ", split(2).text) // الٓمٓ
    }

    @Test fun `An-Naml 27-1 becomes ta seen and keeps the rest of its ayah`() {
        assertTrue(split(27).text.startsWith("طسٓ")) // طسٓ
        assertFalse(split(27).text.contains(BISMILLAH_UTHMANI))
    }

    // -- 27:30 is never touched

    @Test fun `27-30 Bismillah sits mid-ayah inside Sulayman letter`() {
        val text = Fixtures.ayahOne("27:30")
        assertTrue(text.contains(BISMILLAH_UTHMANI))
        assertFalse(text.startsWith(BISMILLAH_UTHMANI))
    }

    @Test fun `27-30 is returned byte-identical`() {
        val text = Fixtures.ayahOne("27:30")
        val result = split(27, numberInSurah = 30, text = text)

        assertEquals(text, result.text)
        assertTrue(text.toByteArray(Charsets.UTF_8).contentEquals(result.text.toByteArray(Charsets.UTF_8)))
        assertNull(result.header)
    }

    // -- safety

    @Test fun `ayahs other than the first are returned unchanged`() {
        val text = "أي نص" // أي نص
        assertEquals(text, split(2, numberInSurah = 2, text = text).text)
        assertNull(split(2, numberInSurah = 2, text = text).header)
    }

    @Test fun `only ayah 1 is split, even when a later ayah starts with the Bismillah`() {
        // Pins the numberInSurah guard on its own: neither 27:30 nor the case
        // above starts with the prefix, so they would pass without it.
        val text = "$BISMILLAH_UTHMANI الٓمٓ"
        val result = split(2, numberInSurah = 2, text = text)
        assertEquals(text, result.text)
        assertNull(result.header)
    }

    @Test fun `an unrecognised orthography is left whole rather than mangled`() {
        // quran-simple uses plain alef (U+0627) where uthmani uses alef wasla (U+0671).
        val simple = SIMPLE_BISMILLAH + " الم"

        val result = split(2, text = simple)

        assertEquals("must not partially strip", simple, result.text)
        assertNull(result.header)
    }

    @Test fun `a caller can supply the prefix for another edition`() {
        val simple = SIMPLE_BISMILLAH + " الم"

        val result = splitOpeningBismillah(surah = 2, numberInSurah = 1, text = simple, bismillah = SIMPLE_BISMILLAH)

        assertEquals(SIMPLE_BISMILLAH, result.header)
        assertEquals("الم", result.text)
    }

    // -- the two surahs the API sends malformed (U+0651 SHADDA on the beh)

    @Test fun `surah 95 carries the malformed spelling upstream`() = assertMalformedUpstream(95)
    @Test fun `surah 97 carries the malformed spelling upstream`() = assertMalformedUpstream(97)
    @Test fun `surah 95 still splits with the canonical header`() = assertSplitsCanonically(95)
    @Test fun `surah 97 still splits with the canonical header`() = assertSplitsCanonically(97)

    @Test fun `the malformed prefix is fully removed, not partially`() {
        for (surah in listOf(95, 97)) {
            val raw = ayahOne(surah)
            val expected = raw.substring(bismillahWithShaddaLength).trimStart()

            assertEquals(expected, split(surah).text)
            assertTrue(split(surah).text.length < raw.length)
        }
    }

    private fun assertMalformedUpstream(surah: Int) {
        assertFalse(ayahOne(surah).startsWith(BISMILLAH_UTHMANI))
        assertEquals("expected the spurious shadda this case exists for", 'ّ', ayahOne(surah)[1])
    }

    private fun assertSplitsCanonically(surah: Int) {
        val result = split(surah)
        assertEquals(BISMILLAH_UTHMANI, result.header)
        assertTrue(result.text.isNotBlank())
        assertFalse(result.text.contains("بِّسْمِ")) // بِّسْمِ
    }

    // -- the Ayah extension the daily repository uses

    @Test fun `withoutOpeningBismillah splits ayah 1 and leaves 27-30 as the same instance`() {
        val baqarah = ayah(surah = 2, numberInSurah = 1, text = ayahOne(2))
        assertEquals("الٓمٓ", baqarah.withoutOpeningBismillah().text)
        assertNotEquals(baqarah, baqarah.withoutOpeningBismillah())

        val letter = ayah(surah = 27, numberInSurah = 30, text = Fixtures.ayahOne("27:30"))
        assertSame(letter, letter.withoutOpeningBismillah())
    }

    private fun ayah(surah: Int, numberInSurah: Int, text: String) = Ayah(
        number = 0,
        numberInSurah = numberInSurah,
        surah = Surah(surah, "", "", "", "", 0),
        text = text,
        sajda = false,
        sajdaObligatory = null,
    )

    private companion object {
        /** بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ in quran-simple orthography (plain alef). */
        const val SIMPLE_BISMILLAH =
            "بِسْمِ " +
                "اللَّهِ " +
                "الرَّحْمَٰنِ " +
                "الرَّحِيمِ"
    }
}
