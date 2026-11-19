package uz.wasira.data

class SettingsRepository(private val store: LocalStore) : SettingsSource {
    override suspend fun read(): Settings = TODO("Agent A")
    override suspend fun setTranslation(identifier: String, name: String?): Unit = TODO("Agent A")
    override suspend fun setArabicFontSize(size: Int): Unit = TODO("Agent A")
    override suspend fun setReminderTime(slot: Int, minutes: Int): Unit = TODO("Agent A")

    companion object {
        val ARABIC_SIZES = listOf(22, 26, 30, 34)
        const val DEFAULT_ARABIC_SIZE = 30
        val DEFAULT_REMINDERS = listOf(480, 660, 840, 1020, 1200)
    }
}
