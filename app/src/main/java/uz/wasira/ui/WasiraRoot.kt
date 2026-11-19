package uz.wasira.ui

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import uz.wasira.R
import uz.wasira.WasiraApp
import uz.wasira.ui.daily.DailyEvent
import uz.wasira.ui.daily.DailyScreen
import uz.wasira.ui.daily.DailyViewModel
import uz.wasira.ui.onboarding.OnboardingScreen
import uz.wasira.ui.onboarding.OnboardingState
import uz.wasira.ui.onboarding.OnboardingViewModel
import uz.wasira.ui.theme.WasiraTheme

/** Builds both ViewModels from the manual dependency container in [WasiraApp]. */
val WasiraViewModelFactory: ViewModelProvider.Factory = viewModelFactory {
    initializer {
        val app = this[APPLICATION_KEY] as WasiraApp
        OnboardingViewModel(api = app.api, settings = app.settings)
    }
    initializer {
        val app = this[APPLICATION_KEY] as WasiraApp
        DailyViewModel(
            daily = app.daily,
            settings = app.settings,
            api = app.api,
            reminders = app.reminders,
            hadith = app.hadith,
        )
    }
}

/**
 * One ayah and one hadith a day. Onboarding until a translation is chosen, then
 * the daily screen, whose two cards each open a page of their own (see
 * [uz.wasira.ui.daily.DailyPage]).
 */
@Composable
fun WasiraRoot() {
    WasiraTheme {
        val onboarding: OnboardingViewModel = viewModel(factory = WasiraViewModelFactory)
        val state by onboarding.state.collectAsStateWithLifecycle()
        when (state) {
            OnboardingState.Ready -> DailyRoute()
            OnboardingState.Loading, is OnboardingState.Failed, is OnboardingState.Choosing ->
                OnboardingScreen(state, onboarding::onEvent)
        }
    }
}

@Composable
private fun DailyRoute() {
    val vm: DailyViewModel = viewModel(factory = WasiraViewModelFactory)
    val state by vm.state.collectAsStateWithLifecycle()
    val translations by vm.translations.collectAsStateWithLifecycle()
    val hadith by vm.hadithState.collectAsStateWithLifecycle()

    // The hadith follows the language the UI is actually showing — uz, ru, en or
    // ar — rather than the device's, which may be one the app has no strings for.
    val language = stringResource(R.string.hadith_language)
    LaunchedEffect(language) { vm.onEvent(DailyEvent.HadithLanguage(language)) }

    // Back from the background on a new day: yesterday's ayah must not stay on screen.
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { vm.onEvent(DailyEvent.Resumed) }

    NotificationPermission { vm.onEvent(DailyEvent.NotificationsPermitted) }

    DailyScreen(state, translations, vm::onEvent, hadith = hadith)
}

/**
 * Asks for POST_NOTIFICATIONS once, after a translation has been chosen, and
 * reports a grant so the reminders can be armed. Below API 33 the permission is
 * implicit and the grant is reported straight away.
 */
@Composable
private fun NotificationPermission(onGranted: () -> Unit) {
    val context = LocalContext.current
    var handled by rememberSaveable { mutableStateOf(false) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) onGranted()
    }
    LaunchedEffect(Unit) {
        if (handled) return@LaunchedEffect
        handled = true
        val granted = Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        if (granted) onGranted() else launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
    }
}
