package uz.wasira.data

import java.io.File
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class SettingsRepositoryTest {
    @get:Rule val tmp = TemporaryFolder()

    private lateinit var store: LocalStore
    private lateinit var settings: SettingsRepository

    @Before fun setUp() {
        store = LocalStore(File(tmp.root, "settings.json"))
        settings = SettingsRepository(store)
    }

    private fun reopened() = SettingsRepository(LocalStore(store.file))

    private fun raw(json: String) = store.write(Json.parseToJsonElement(json).jsonObject)

    // -- reminders

    @Test fun `reminders are five, spread across the waking day`() = runTest {
        assertEquals(listOf(8 * 60, 11 * 60, 14 * 60, 17 * 60, 20 * 60), settings.read().reminderTimes)
        assertEquals(SettingsRepository.DEFAULT_REMINDERS, settings.read().reminderTimes)
    }

    @Test fun `moving one keeps it and leaves the others alone`() = runTest {
        settings.setReminderTime(2, 6 * 60 + 30)
        assertEquals(listOf(480, 660, 390, 1020, 1200), reopened().read().reminderTimes)
    }

    @Test fun `an out-of-range time is clamped rather than stored`() = runTest {
        settings.setReminderTime(0, 99999)
        settings.setReminderTime(1, -5)
        val times = reopened().read().reminderTimes
        assertEquals(1439, times[0])
        assertEquals(0, times[1])
    }

    @Test fun `a slot outside the five is ignored`() = runTest {
        settings.setReminderTime(5, 600)
        settings.setReminderTime(-1, 600)
        assertEquals(SettingsRepository.DEFAULT_REMINDERS, reopened().read().reminderTimes)
        assertFalse(store.file.exists())
    }

    @Test fun `never more than five, however many are on disk`() = runTest {
        raw("""{"reminder_times": [600,600,600,600,600,600,600,600,600,600]}""")
        assertEquals(List(5) { 600 }, settings.read().reminderTimes)
    }

    @Test fun `invalid entries on disk are dropped and padded with defaults`() = runTest {
        raw("""{"reminder_times": [1, "2", 3.5, null, true, 1440, -1, 4]}""")
        assertEquals(listOf(1, 4, 840, 1020, 1200), settings.read().reminderTimes)

        raw("""{"reminder_times": "not a list"}""")
        assertEquals(SettingsRepository.DEFAULT_REMINDERS, settings.read().reminderTimes)
    }

    @Test fun `reminder times are stored as five integers`() = runTest {
        settings.setReminderTime(4, 100)
        assertEquals(
            Json.parseToJsonElement("[480,660,840,1020,100]"),
            store.read()["reminder_times"],
        )
    }

    // -- settings on disk

    @Test fun `settings survive being reopened`() = runTest {
        settings.setArabicFontSize(22)
        settings.setTranslation("uz.sodik", null)

        val again = reopened().read()
        assertEquals(22, again.arabicFontSize)
        assertEquals("uz.sodik", again.translationEdition)
    }

    @Test fun `an unoffered size is ignored rather than rendered`() = runTest {
        settings.setArabicFontSize(99)
        assertEquals(SettingsRepository.DEFAULT_ARABIC_SIZE, settings.read().arabicFontSize)
        assertFalse(store.file.exists())
    }

    @Test fun `an unknown size on disk falls back`() = runTest {
        raw("""{"arabic_font_size": 99}""")
        assertEquals(30, settings.read().arabicFontSize)
        raw("""{"arabic_font_size": "22"}""")
        assertEquals(30, settings.read().arabicFontSize)
        // The Flutter build wrote doubles.
        raw("""{"arabic_font_size": 26.0}""")
        assertEquals(26, settings.read().arabicFontSize)
    }

    @Test fun `a corrupt file reads as a first launch, not a crash`() = runTest {
        store.file.writeText("{ this is not json")

        val read = settings.read()
        assertNull(read.translationEdition)
        assertEquals(SettingsRepository.DEFAULT_ARABIC_SIZE, read.arabicFontSize)
        assertEquals(SettingsRepository.DEFAULT_REMINDERS, read.reminderTimes)
    }

    @Test fun `a setter on a corrupt file starts over rather than throwing`() = runTest {
        store.file.writeText("[]")
        settings.setArabicFontSize(34)
        assertEquals(34, settings.read().arabicFontSize)
    }

    // -- the translation

    @Test fun `the translation survives a relaunch, name and all`() = runTest {
        settings.setTranslation("uz.sodik", "Muhammad Sodik")

        val again = reopened().read()
        assertEquals("uz.sodik", again.translationEdition)
        assertEquals("Muhammad Sodik", again.translationName)
        assertEquals("Muhammad Sodik", again.translationLabel)
    }

    @Test fun `an edition stored without a name falls back to the identifier`() = runTest {
        // Written by an older build, or by hand.
        store.write(JsonObject(mapOf("translation_edition" to JsonPrimitive("en.sahih"))))

        val read = settings.read()
        assertNull(read.translationName)
        assertEquals("en.sahih", read.translationLabel)
    }

    @Test fun `the name is only written when there is one`() = runTest {
        settings.setTranslation("en.sahih", null)
        assertEquals(setOf("translation_edition"), store.read().keys)
    }

    @Test fun `a new edition without a name does not keep the old edition's name`() = runTest {
        settings.setTranslation("en.sahih", "Saheeh International")
        settings.setTranslation("uz.sodik", null)

        assertEquals("uz.sodik", settings.read().translationLabel)
    }

    @Test fun `no translation until one is chosen`() = runTest {
        assertNull(settings.read().translationEdition)
        raw("""{"translation_edition": ""}""")
        assertNull(settings.read().translationEdition)
    }

    @Test fun `setters keep the keys they do not touch`() = runTest {
        settings.setTranslation("en.sahih", "Saheeh International")
        settings.setArabicFontSize(26)
        settings.setReminderTime(0, 0)

        val read = reopened().read()
        assertEquals("en.sahih", read.translationEdition)
        assertEquals("Saheeh International", read.translationName)
        assertEquals(26, read.arabicFontSize)
        assertEquals(0, read.reminderTimes[0])
    }
}
