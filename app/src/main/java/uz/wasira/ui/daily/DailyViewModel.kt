package uz.wasira.ui.daily

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import java.time.Duration
import java.time.LocalDateTime
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import uz.wasira.data.DailySource
import uz.wasira.data.HadithSource
import uz.wasira.data.QuranApi
import uz.wasira.data.ReminderScheduler
import uz.wasira.data.Settings
import uz.wasira.data.SettingsSource
import uz.wasira.domain.DailyAyah
import uz.wasira.domain.DailyHadith
import uz.wasira.domain.Edition

sealed interface DailyEvent {
    /** Show today's ayah: from the cache if it is today's, otherwise fetched. */
    data object Requested : DailyEvent

    /** Try again after a failed fetch. */
    data object Retried : DailyEvent

    /**
     * The app came back to the foreground, or the clock passed midnight. Reloads
     * only if what is on screen is no longer today's: yesterday's ayah must not
     * survive midnight.
     */
    data object Resumed : DailyEvent

    data object TranslationExpanded : DailyEvent

    data class ArabicSizeChanged(val size: Int) : DailyEvent

    /** A different translation was chosen. The ayah on screen was fetched against the old one, so refetch. */
    data class TranslationChanged(val id: String, val name: String) : DailyEvent

    /** One reminder moved. [minutes] after local midnight; [slot] is 0..4. */
    data class ReminderTimeChanged(val slot: Int, val minutes: Int) : DailyEvent

    /** The settings picker opened: fetch every translation the API offers. */
    data object TranslationsRequested : DailyEvent

    /** POST_NOTIFICATIONS was granted: arm the five reminders. */
    data object NotificationsPermitted : DailyEvent

    /**
     * The screen is showing in [language], an ISO 639 code: on first composition
     * and whenever the UI language changes. The hadith follows it.
     */
    data class HadithLanguage(val language: String) : DailyEvent

    /** Try the hadith again after a failed fetch. The ayah is not refetched. */
    data object HadithRetried : DailyEvent

    /** Show a long hadith in full. */
    data object HadithExpanded : DailyEvent

    /** Open or close the hadith's explanation. */
    data object HadithExplanationToggled : DailyEvent
}

sealed interface DailyState {
    data object Loading : DailyState

    /** The ayah could not be fetched and none is cached for today. The app needs the network once a day; this was that once. */
    data object Unavailable : DailyState

    data class Loaded(
        val ayah: DailyAyah,
        val settings: Settings,
        /** Whether a long translation is shown in full. */
        val expanded: Boolean = false,
    ) : DailyState
}

/**
 * The hadith of the day. Apart from [DailyState] because the two are fetched
 * from different services and either can fail without the other.
 */
sealed interface HadithState {
    /** No UI language has been reported yet, so nothing has been asked for. */
    data object Idle : HadithState
    data object Loading : HadithState
    data object Unavailable : HadithState

    data class Loaded(
        val daily: DailyHadith,
        /** Whether a long hadith is shown in full. */
        val expanded: Boolean = false,
        val explanationOpen: Boolean = false,
    ) : HadithState
}

/** The live translation list for the settings picker. Fetched when asked for, not held. */
sealed interface TranslationsState {
    data object Idle : TranslationsState
    data object Loading : TranslationsState
    data object Failed : TranslationsState
    data class Loaded(val editions: List<Edition>) : TranslationsState
}

/**
 * The ayah of the day and the things about it the user can change. Ported from
 * lib/ui/daily/daily_bloc.dart.
 */
class DailyViewModel(
    private val daily: DailySource,
    private val settings: SettingsSource,
    private val api: QuranApi,
    private val reminders: ReminderScheduler,
    private val hadith: HadithSource,
    private val now: () -> LocalDateTime = LocalDateTime::now,
) : ViewModel() {
    private val _state = MutableStateFlow<DailyState>(DailyState.Loading)
    val state: StateFlow<DailyState> = _state.asStateFlow()

    private val _translations = MutableStateFlow<TranslationsState>(TranslationsState.Idle)
    val translations: StateFlow<TranslationsState> = _translations.asStateFlow()

    private val _hadith = MutableStateFlow<HadithState>(HadithState.Idle)
    val hadithState: StateFlow<HadithState> = _hadith.asStateFlow()

    private var loadJob: Job? = null
    private var hadithJob: Job? = null

    /** The UI language last reported; null until the screen has composed. */
    private var language: String? = null
    private var midnightJob: Job? = null

    init {
        onEvent(DailyEvent.Requested)
    }

    fun onEvent(e: DailyEvent) {
        when (e) {
            DailyEvent.Requested, DailyEvent.Retried -> load()
            DailyEvent.Resumed -> {
                if (isStale()) load()
                if (isHadithStale()) loadHadith()
            }
            DailyEvent.TranslationExpanded -> _state.update {
                if (it is DailyState.Loaded) it.copy(expanded = true) else it
            }
            is DailyEvent.ArabicSizeChanged -> viewModelScope.launch {
                settings.setArabicFontSize(e.size)
                refreshSettings()
            }
            is DailyEvent.TranslationChanged -> {
                loadJob?.cancel()
                loadJob = viewModelScope.launch {
                    settings.setTranslation(e.id, e.name)
                    fetch()
                }
            }
            is DailyEvent.ReminderTimeChanged -> viewModelScope.launch {
                settings.setReminderTime(e.slot, e.minutes)
                val current = refreshSettings()
                schedule(current.reminderTimes)
            }
            DailyEvent.TranslationsRequested -> loadTranslations()
            DailyEvent.NotificationsPermitted -> viewModelScope.launch {
                schedule(settings.read().reminderTimes)
            }
            is DailyEvent.HadithLanguage -> if (e.language != language) {
                language = e.language
                loadHadith()
            }
            DailyEvent.HadithRetried -> loadHadith()
            DailyEvent.HadithExpanded -> _hadith.update {
                if (it is HadithState.Loaded) it.copy(expanded = true) else it
            }
            DailyEvent.HadithExplanationToggled -> _hadith.update {
                if (it is HadithState.Loaded) it.copy(explanationOpen = !it.explanationOpen) else it
            }
        }
    }

    /** True when what is on screen is not today's — or nothing is, and it is worth trying again. */
    private fun isStale(): Boolean = when (val s = _state.value) {
        is DailyState.Loaded -> s.ayah.date != now().toLocalDate().toString()
        DailyState.Unavailable -> true
        DailyState.Loading -> false
    }

    /** Like [isStale], for the hadith. Nothing to refresh before a language has been reported. */
    private fun isHadithStale(): Boolean = when (val s = _hadith.value) {
        is HadithState.Loaded -> s.daily.date != now().toLocalDate().toString()
        HadithState.Unavailable -> true
        HadithState.Loading, HadithState.Idle -> false
    }

    private fun loadHadith() {
        val language = language ?: return
        hadithJob?.cancel()
        hadithJob = viewModelScope.launch {
            _hadith.value = HadithState.Loading
            _hadith.value = try {
                HadithState.Loaded(hadith.today(language))
            } catch (c: CancellationException) {
                throw c
            } catch (_: Exception) {
                HadithState.Unavailable
            }
        }
    }

    private fun load() {
        loadJob?.cancel()
        loadJob = viewModelScope.launch { fetch() }
    }

    private suspend fun fetch() {
        _state.value = DailyState.Loading
        _state.value = try {
            DailyState.Loaded(ayah = daily.today(), settings = settings.read())
        } catch (c: CancellationException) {
            throw c
        } catch (_: Exception) {
            DailyState.Unavailable
        }
        armMidnight()
    }

    /** Re-checks the day just after the next local midnight, for an app left open overnight. */
    private fun armMidnight() {
        midnightJob?.cancel()
        val start = now()
        val midnight = start.toLocalDate().plusDays(1).atStartOfDay()
        val wait = Duration.between(start, midnight).toMillis() + MIDNIGHT_SLACK_MS
        midnightJob = viewModelScope.launch {
            delay(wait)
            onEvent(DailyEvent.Resumed)
        }
    }

    private suspend fun refreshSettings(): Settings {
        val current = settings.read()
        _state.update { if (it is DailyState.Loaded) it.copy(settings = current) else it }
        return current
    }

    /** A reminder that cannot be scheduled must not stop the ayah being shown. */
    private fun schedule(times: List<Int>) {
        try {
            if (reminders.canNotify()) reminders.schedule(times)
        } catch (_: Exception) {
        }
    }

    private fun loadTranslations() {
        if (_translations.value is TranslationsState.Loaded ||
            _translations.value is TranslationsState.Loading
        ) return
        viewModelScope.launch {
            _translations.value = TranslationsState.Loading
            _translations.value = try {
                TranslationsState.Loaded(api.translations())
            } catch (c: CancellationException) {
                throw c
            } catch (_: Exception) {
                TranslationsState.Failed
            }
        }
    }

    private companion object {
        const val MIDNIGHT_SLACK_MS = 1_000L
    }
}
