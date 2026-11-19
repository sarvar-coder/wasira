package uz.wasira.ui.daily

import java.time.LocalDateTime
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import uz.wasira.ui.FakeApi
import uz.wasira.ui.FakeDaily
import uz.wasira.ui.FakeHadith
import uz.wasira.ui.FakeReminders
import uz.wasira.ui.FakeSettings
import uz.wasira.ui.MainDispatcherRule

class DailyViewModelTest {
    @get:Rule val main = MainDispatcherRule()

    private var now = LocalDateTime.of(2026, 11, 19, 10, 0)
    private val settings = FakeSettings().apply {
        value = value.copy(translationEdition = "en.sahih", translationName = "Saheeh International")
    }
    private val daily = FakeDaily(clock = { now })
    private val api = FakeApi()
    private val reminders = FakeReminders()
    private val hadith = FakeHadith(clock = { now })

    private fun TestScope.loaded(): DailyViewModel {
        val vm = DailyViewModel(daily, settings, api, reminders, hadith, now = { now })
        testScheduler.runCurrent()
        return vm
    }

    private val DailyViewModel.loadedState get() = state.value as DailyState.Loaded

    @Test fun `starts loading`() {
        assertEquals(DailyState.Loading, DailyViewModel(daily, settings, api, reminders, hadith).state.value)
    }

    @Test fun `requested - loaded with today's ayah and the settings`() = runTest(main.dispatcher) {
        val vm = loaded()
        val s = vm.loadedState
        assertEquals("2026-11-19", s.ayah.date)
        assertEquals(255, s.ayah.ayah.numberInSurah)
        assertEquals(settings.value, s.settings)
    }

    @Test fun `failure - unavailable, and retry refetches`() = runTest(main.dispatcher) {
        daily.failures = 1
        val vm = loaded()
        assertEquals(DailyState.Unavailable, vm.state.value)

        vm.onEvent(DailyEvent.Retried)
        testScheduler.runCurrent()
        assertTrue(vm.state.value is DailyState.Loaded)
        assertEquals(2, daily.calls)
    }

    @Test fun `arabic size changed - saved and shown`() = runTest(main.dispatcher) {
        val vm = loaded()
        vm.onEvent(DailyEvent.ArabicSizeChanged(22))
        testScheduler.runCurrent()
        assertEquals(22, settings.value.arabicFontSize)
        assertEquals(22, vm.loadedState.settings.arabicFontSize)
        assertEquals(1, daily.calls)
    }

    @Test fun `translation changed - saved and refetched`() = runTest(main.dispatcher) {
        val vm = loaded()
        vm.onEvent(DailyEvent.TranslationChanged("ur.jalandhry", "Jalandhry"))
        testScheduler.runCurrent()
        assertEquals("ur.jalandhry", settings.value.translationEdition)
        assertEquals(2, daily.calls)
        assertEquals("Jalandhry", vm.loadedState.settings.translationName)
    }

    @Test fun `reminder time changed - saved and rescheduled when permitted`() = runTest(main.dispatcher) {
        val vm = loaded()
        vm.onEvent(DailyEvent.ReminderTimeChanged(2, 900))
        testScheduler.runCurrent()
        val expected = listOf(480, 660, 900, 1020, 1200)
        assertEquals(expected, settings.value.reminderTimes)
        assertEquals(expected, vm.loadedState.settings.reminderTimes)
        assertEquals(listOf(expected), reminders.scheduled)
    }

    @Test fun `reminder time changed - saved but not scheduled without permission`() = runTest(main.dispatcher) {
        reminders.permitted = false
        val vm = loaded()
        vm.onEvent(DailyEvent.ReminderTimeChanged(0, 300))
        testScheduler.runCurrent()
        assertEquals(300, vm.loadedState.settings.reminderTimes[0])
        assertTrue(reminders.scheduled.isEmpty())
    }

    @Test fun `notifications permitted - the five reminders are armed`() = runTest(main.dispatcher) {
        val vm = loaded()
        vm.onEvent(DailyEvent.NotificationsPermitted)
        testScheduler.runCurrent()
        assertEquals(listOf(settings.value.reminderTimes), reminders.scheduled)
    }

    @Test fun `resumed the same day - nothing refetched`() = runTest(main.dispatcher) {
        val vm = loaded()
        now = now.plusHours(5)
        vm.onEvent(DailyEvent.Resumed)
        testScheduler.runCurrent()
        assertEquals(1, daily.calls)
    }

    @Test fun `resumed on a new day - yesterday's ayah is replaced`() = runTest(main.dispatcher) {
        val vm = loaded()
        now = now.plusDays(1)
        vm.onEvent(DailyEvent.Resumed)
        testScheduler.runCurrent()
        assertEquals(2, daily.calls)
        assertEquals("2026-11-20", vm.loadedState.ayah.date)
    }

    @Test fun `resumed while unavailable - tries again`() = runTest(main.dispatcher) {
        daily.failures = 1
        val vm = loaded()
        vm.onEvent(DailyEvent.Resumed)
        testScheduler.runCurrent()
        assertTrue(vm.state.value is DailyState.Loaded)
    }

    @Test fun `left open past midnight - replaced without a resume`() = runTest(main.dispatcher) {
        now = LocalDateTime.of(2026, 11, 19, 23, 59, 0)
        val vm = loaded()
        assertEquals("2026-11-19", vm.loadedState.ayah.date)

        now = LocalDateTime.of(2026, 11, 20, 0, 0, 2)
        testScheduler.advanceTimeBy(62_000)
        testScheduler.runCurrent()
        assertEquals(2, daily.calls)
        assertEquals("2026-11-20", vm.loadedState.ayah.date)
    }

    @Test fun `translations requested - fetched once and listed`() = runTest(main.dispatcher) {
        val vm = loaded()
        assertEquals(TranslationsState.Idle, vm.translations.value)
        vm.onEvent(DailyEvent.TranslationsRequested)
        testScheduler.runCurrent()
        assertEquals(TranslationsState.Loaded(api.editions), vm.translations.value)
        vm.onEvent(DailyEvent.TranslationsRequested)
        testScheduler.runCurrent()
        assertEquals(1, api.translationCalls)
    }

    @Test fun `translations failed - asking again retries`() = runTest(main.dispatcher) {
        api.failures = 1
        val vm = loaded()
        vm.onEvent(DailyEvent.TranslationsRequested)
        testScheduler.runCurrent()
        assertEquals(TranslationsState.Failed, vm.translations.value)
        vm.onEvent(DailyEvent.TranslationsRequested)
        testScheduler.runCurrent()
        assertEquals(TranslationsState.Loaded(api.editions), vm.translations.value)
    }

    private val DailyViewModel.loadedHadith get() = hadithState.value as HadithState.Loaded

    @Test fun `no hadith is asked for before the UI language is known`() = runTest(main.dispatcher) {
        val vm = loaded()
        assertEquals(HadithState.Idle, vm.hadithState.value)
        assertTrue(hadith.languages.isEmpty())
    }

    @Test fun `hadith language - fetched in that language`() = runTest(main.dispatcher) {
        val vm = loaded()
        vm.onEvent(DailyEvent.HadithLanguage("uz"))
        testScheduler.runCurrent()
        assertEquals("uz", vm.loadedHadith.daily.hadith.language)
        assertEquals(listOf("uz"), hadith.languages)
    }

    @Test fun `the same language reported again - not refetched`() = runTest(main.dispatcher) {
        val vm = loaded()
        vm.onEvent(DailyEvent.HadithLanguage("uz"))
        vm.onEvent(DailyEvent.HadithLanguage("uz"))
        testScheduler.runCurrent()
        assertEquals(listOf("uz"), hadith.languages)
    }

    @Test fun `a new language - refetched in it`() = runTest(main.dispatcher) {
        val vm = loaded()
        vm.onEvent(DailyEvent.HadithLanguage("uz"))
        testScheduler.runCurrent()
        vm.onEvent(DailyEvent.HadithLanguage("ru"))
        testScheduler.runCurrent()
        assertEquals("ru", vm.loadedHadith.daily.hadith.language)
    }

    @Test fun `hadith failure leaves the ayah loaded, and retry refetches only the hadith`() = runTest(main.dispatcher) {
        hadith.failures = 1
        val vm = loaded()
        vm.onEvent(DailyEvent.HadithLanguage("en"))
        testScheduler.runCurrent()
        assertEquals(HadithState.Unavailable, vm.hadithState.value)
        assertTrue(vm.state.value is DailyState.Loaded)

        vm.onEvent(DailyEvent.HadithRetried)
        testScheduler.runCurrent()
        assertTrue(vm.hadithState.value is HadithState.Loaded)
        assertEquals(1, daily.calls)
    }

    @Test fun `ayah failure does not stop the hadith`() = runTest(main.dispatcher) {
        daily.failures = 1
        val vm = loaded()
        vm.onEvent(DailyEvent.HadithLanguage("en"))
        testScheduler.runCurrent()
        assertEquals(DailyState.Unavailable, vm.state.value)
        assertTrue(vm.hadithState.value is HadithState.Loaded)
    }

    @Test fun `translation changed - the hadith is not redrawn`() = runTest(main.dispatcher) {
        val vm = loaded()
        vm.onEvent(DailyEvent.HadithLanguage("en"))
        testScheduler.runCurrent()
        vm.onEvent(DailyEvent.TranslationChanged("ur.jalandhry", "Jalandhry"))
        testScheduler.runCurrent()
        assertEquals(listOf("en"), hadith.languages)
    }

    @Test fun `resumed on a new day - yesterday's hadith is replaced too`() = runTest(main.dispatcher) {
        val vm = loaded()
        vm.onEvent(DailyEvent.HadithLanguage("en"))
        testScheduler.runCurrent()
        now = now.plusDays(1)
        vm.onEvent(DailyEvent.Resumed)
        testScheduler.runCurrent()
        assertEquals("2026-11-20", vm.loadedHadith.daily.date)
        assertEquals(listOf("en", "en"), hadith.languages)
    }

    @Test fun `resumed the same day - the hadith is not refetched`() = runTest(main.dispatcher) {
        val vm = loaded()
        vm.onEvent(DailyEvent.HadithLanguage("en"))
        testScheduler.runCurrent()
        vm.onEvent(DailyEvent.Resumed)
        testScheduler.runCurrent()
        assertEquals(listOf("en"), hadith.languages)
    }
}
