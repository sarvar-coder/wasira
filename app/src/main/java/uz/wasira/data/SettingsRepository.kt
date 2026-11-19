package uz.wasira.data

class SettingsRepository(private val store: LocalStore) {
    suspend fun read(): Settings = TODO("Agent A")
    suspend fun setTranslation(identifier: String, name: String?): Unit = TODO("Agent A")
    /** Ignores values not in [ARABIC_SIZES]. */
    suspend fun setArabicFontSize(size: Int): Unit = TODO("Agent A")
    /** Clamps [minutes] to 0..1439; [slot] is 0..4. */
    suspend fun setReminderTime(slot: Int, minutes: Int): Unit = TODO("Agent A")

    companion object {
        val ARABIC_SIZES = listOf(22, 26, 30, 34)
        const val DEFAULT_ARABIC_SIZE = 30
        val DEFAULT_REMINDERS = listOf(480, 660, 840, 1020, 1200)
    }
}
