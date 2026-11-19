package uz.wasira.data

import java.time.LocalDate
import kotlin.random.Random
import uz.wasira.domain.DailyAyah

class DailyRepository(
    private val api: QuranApi,
    private val store: LocalStore,
    private val settings: SettingsSource,
    private val today: () -> LocalDate = LocalDate::now,
    private val random: Random = Random.Default,
) : DailySource {
    override suspend fun today(): DailyAyah = TODO("Agent A")
}
