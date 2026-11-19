package uz.wasira.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.doubleOrNull

/** Preferences that outlive a launch, in settings.json. */
class SettingsRepository(private val store: LocalStore) : SettingsSource {
    /** Serialises read-modify-write so two setters cannot drop each other's change. */
    private val writes = Mutex()

    override suspend fun read(): Settings = withContext(Dispatchers.IO) {
        val json = store.read()
        Settings(
            translationEdition = json.nonEmptyString(TRANSLATION_KEY),
            translationName = json.nonEmptyString(TRANSLATION_NAME_KEY),
            arabicFontSize = parseArabicSize(json[ARABIC_SIZE_KEY]),
            reminderTimes = parseReminders(json[REMINDER_TIMES_KEY]),
        )
    }

    /**
     * [name] is the edition's English name, kept only so settings can say
     * "Saheeh International" instead of "en.sahih". When it is null the key is
     * removed, so a name belonging to the previous edition is never shown.
     */
    override suspend fun setTranslation(identifier: String, name: String?) = edit { json ->
        val next = json.toMutableMap()
        next[TRANSLATION_KEY] = JsonPrimitive(identifier)
        if (name != null) next[TRANSLATION_NAME_KEY] = JsonPrimitive(name) else next.remove(TRANSLATION_NAME_KEY)
        next
    }

    override suspend fun setArabicFontSize(size: Int) {
        if (size !in ARABIC_SIZES) return
        edit { it + (ARABIC_SIZE_KEY to JsonPrimitive(size)) }
    }

    override suspend fun setReminderTime(slot: Int, minutes: Int) {
        if (slot !in 0 until REMINDER_COUNT) return
        edit { json ->
            val times = parseReminders(json[REMINDER_TIMES_KEY]).toMutableList()
            times[slot] = minutes.coerceIn(0, LAST_MINUTE)
            json + (REMINDER_TIMES_KEY to JsonArray(times.map(::JsonPrimitive)))
        }
    }

    private suspend fun edit(change: (JsonObject) -> Map<String, JsonElement>) {
        withContext(Dispatchers.IO) {
            writes.withLock { store.write(JsonObject(change(store.read()))) }
        }
    }

    companion object {
        val ARABIC_SIZES = listOf(22, 26, 30, 34)
        const val DEFAULT_ARABIC_SIZE = 30
        val DEFAULT_REMINDERS = listOf(480, 660, 840, 1020, 1200)

        private const val REMINDER_COUNT = 5
        private const val LAST_MINUTE = 1439

        private const val ARABIC_SIZE_KEY = "arabic_font_size"
        private const val REMINDER_TIMES_KEY = "reminder_times"
        private const val TRANSLATION_KEY = "translation_edition"
        private const val TRANSLATION_NAME_KEY = "translation_name"

        private fun JsonObject.nonEmptyString(key: String): String? =
            (this[key] as? JsonPrimitive)?.takeIf { it.isString }?.content?.takeIf { it.isNotEmpty() }

        /** Any number equal to an offered size (22 or 22.0); anything else falls back. */
        private fun parseArabicSize(element: JsonElement?): Int {
            val value = (element as? JsonPrimitive)?.takeIf { !it.isString }?.doubleOrNull
            return ARABIC_SIZES.firstOrNull { it.toDouble() == value } ?: DEFAULT_ARABIC_SIZE
        }

        /** Always five: integer entries in 0..1439 kept in order, the rest padded with defaults. */
        private fun parseReminders(element: JsonElement?): List<Int> {
            val parsed = (element as? JsonArray).orEmpty().mapNotNull { entry ->
                (entry as? JsonPrimitive)?.takeIf { !it.isString }?.content?.toIntOrNull()
                    ?.takeIf { it in 0..LAST_MINUTE }
            }
            return List(REMINDER_COUNT) { i -> parsed.getOrNull(i) ?: DEFAULT_REMINDERS[i] }
        }
    }
}
