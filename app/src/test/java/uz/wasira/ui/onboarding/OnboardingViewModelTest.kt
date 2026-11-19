package uz.wasira.ui.onboarding

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import uz.wasira.ui.FakeApi
import uz.wasira.ui.FakeSettings
import uz.wasira.ui.MainDispatcherRule
import uz.wasira.ui.SAHIH

class OnboardingViewModelTest {
    @get:Rule val main = MainDispatcherRule()

    private val api = FakeApi()
    private val settings = FakeSettings()

    @Test fun `starts loading`() {
        assertEquals(OnboardingState.Loading, OnboardingViewModel(api, settings).state.value)
    }

    @Test fun `no translation yet - lists every edition`() = runTest(main.dispatcher) {
        val vm = OnboardingViewModel(api, settings)
        testScheduler.advanceUntilIdle()
        assertEquals(OnboardingState.Choosing(api.editions), vm.state.value)
    }

    @Test fun `translation already chosen - straight to ready without the network`() = runTest(main.dispatcher) {
        settings.setTranslation("en.sahih", "Saheeh International")
        val vm = OnboardingViewModel(api, settings)
        testScheduler.advanceUntilIdle()
        assertEquals(OnboardingState.Ready, vm.state.value)
        assertEquals(0, api.translationCalls)
    }

    @Test fun `failure - then retry recovers`() = runTest(main.dispatcher) {
        api.failures = 1
        val vm = OnboardingViewModel(api, settings)
        testScheduler.advanceUntilIdle()
        assertEquals(OnboardingState.Failed("offline"), vm.state.value)

        vm.onEvent(OnboardingEvent.Retried)
        testScheduler.advanceUntilIdle()
        assertEquals(OnboardingState.Choosing(api.editions), vm.state.value)
    }

    @Test fun `requested again re-reads settings`() = runTest(main.dispatcher) {
        val vm = OnboardingViewModel(api, settings)
        testScheduler.advanceUntilIdle()
        settings.setTranslation("en.sahih", null)
        vm.onEvent(OnboardingEvent.Requested)
        testScheduler.advanceUntilIdle()
        assertEquals(OnboardingState.Ready, vm.state.value)
    }

    @Test fun `choosing saves the translation and its name`() = runTest(main.dispatcher) {
        val vm = OnboardingViewModel(api, settings)
        testScheduler.advanceUntilIdle()
        vm.onEvent(OnboardingEvent.TranslationChosen(SAHIH.identifier, SAHIH.englishName))
        testScheduler.advanceUntilIdle()
        assertEquals(OnboardingState.Ready, vm.state.value)
        assertEquals("en.sahih", settings.value.translationEdition)
        assertEquals("Saheeh International", settings.value.translationName)
    }
}
