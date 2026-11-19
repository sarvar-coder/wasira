package uz.wasira.ui.onboarding

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import uz.wasira.data.QuranApi
import uz.wasira.data.SettingsSource
import uz.wasira.domain.Edition

sealed interface OnboardingEvent {
    /** Open the picker: skip it if a translation is already chosen, else load every translation. */
    data object Requested : OnboardingEvent

    /** Try again after the editions failed to load. */
    data object Retried : OnboardingEvent

    /** The user chose a translation. Nothing downloads; the ayah is fetched when the day needs it. */
    data class TranslationChosen(val id: String, val englishName: String) : OnboardingEvent
}

sealed interface OnboardingState {
    data object Loading : OnboardingState
    data class Failed(val message: String) : OnboardingState
    data class Choosing(val editions: List<Edition>) : OnboardingState
    data object Ready : OnboardingState
}

/**
 * Choosing a translation, which is the only thing the app asks before it can
 * show an ayah. Ported from lib/ui/onboarding/onboarding_bloc.dart.
 */
class OnboardingViewModel(
    private val api: QuranApi,
    private val settings: SettingsSource,
) : ViewModel() {
    private val _state = MutableStateFlow<OnboardingState>(OnboardingState.Loading)
    val state: StateFlow<OnboardingState> = _state.asStateFlow()

    private var job: Job? = null

    init {
        onEvent(OnboardingEvent.Requested)
    }

    fun onEvent(e: OnboardingEvent) {
        when (e) {
            OnboardingEvent.Requested, OnboardingEvent.Retried -> load()
            is OnboardingEvent.TranslationChosen -> choose(e.id, e.englishName)
        }
    }

    private fun load() {
        job?.cancel()
        job = viewModelScope.launch {
            _state.value = OnboardingState.Loading
            _state.value = try {
                if (settings.read().translationEdition != null) {
                    OnboardingState.Ready
                } else {
                    OnboardingState.Choosing(api.translations())
                }
            } catch (c: CancellationException) {
                throw c
            } catch (t: Exception) {
                OnboardingState.Failed(t.message ?: t.toString())
            }
        }
    }

    private fun choose(id: String, englishName: String) {
        job?.cancel()
        job = viewModelScope.launch {
            settings.setTranslation(id, englishName)
            _state.value = OnboardingState.Ready
        }
    }
}
