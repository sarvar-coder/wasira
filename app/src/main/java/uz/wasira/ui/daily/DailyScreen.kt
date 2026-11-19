package uz.wasira.ui.daily

import android.content.ClipData
import uz.wasira.ui.components.page
import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.background
import androidx.compose.animation.togetherWith
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.fadeOut
import androidx.compose.animation.fadeIn
import androidx.compose.animation.AnimatedContent
import androidx.activity.compose.BackHandler
import uz.wasira.domain.citation
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ClipEntry
import androidx.compose.ui.platform.LocalClipboard
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import uz.wasira.R
import uz.wasira.ui.components.AmiriLatin
import uz.wasira.ui.components.SectionCard
import uz.wasira.ui.components.SectionTone
import uz.wasira.ui.theme.wasira

/**
 * The whole app: today's ayah and today's hadith as two cards that fit any
 * screen, each opening its own page with all of it.
 */
@Composable
fun DailyScreen(
    state: DailyState,
    translations: TranslationsState,
    onEvent: (DailyEvent) -> Unit,
    modifier: Modifier = Modifier,
    hadith: HadithState = HadithState.Idle,
) {
    val snackbar = remember { SnackbarHostState() }
    Scaffold(
        modifier = modifier,
        snackbarHost = { SnackbarHost(snackbar) },
        containerColor = MaterialTheme.wasira.bg,
    ) { insets ->
        // Each page pads for the system bars itself and paints its own background.
        Box(Modifier.fillMaxSize()) {
            when (state) {
                DailyState.Loading -> CircularProgressIndicator(Modifier.align(Alignment.Center))
                DailyState.Unavailable -> Unavailable(
                    onRetry = { onEvent(DailyEvent.Retried) },
                    modifier = Modifier.align(Alignment.Center).padding(insets),
                )
                is DailyState.Loaded -> Loaded(state, translations, hadith, snackbar, insets, onEvent)
            }
        }
    }
}

/** The app needs the network once a day. This is that once, and it failed. */
@Composable
private fun Unavailable(onRetry: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier.padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            stringResource(R.string.service_unreachable),
            textAlign = TextAlign.Center,
            color = MaterialTheme.wasira.muted,
        )
        Spacer(Modifier.height(12.dp))
        FilledTonalButton(onClick = onRetry) { Text(stringResource(R.string.try_again)) }
    }
}

/**
 * Where the daily screen is. A stack two deep: home, and the page of whichever
 * card was tapped. An enum so it survives rotation and process death.
 */
enum class DailyPage { Home, Ayah, Hadith }

@Composable
private fun Loaded(
    state: DailyState.Loaded,
    translations: TranslationsState,
    hadith: HadithState,
    snackbar: SnackbarHostState,
    insets: PaddingValues,
    onEvent: (DailyEvent) -> Unit,
) {
    var page by rememberSaveable { mutableStateOf(DailyPage.Home) }
    var settingsOpen by rememberSaveable { mutableStateOf(false) }

    // The hadith page has nothing to show once the hadith is gone, as at midnight.
    if (page == DailyPage.Hadith && hadith !is HadithState.Loaded) page = DailyPage.Home

    BackHandler(enabled = page != DailyPage.Home) { page = DailyPage.Home }

    AnimatedContent(
        targetState = page,
        transitionSpec = {
            // Pushing slides the page in from the end edge; popping slides it back out.
            // Offsets are in layout direction, so this mirrors in Arabic.
            val push = targetState != DailyPage.Home
            if (push) {
                (slideInHorizontally { it } + fadeIn()) togetherWith
                    (slideOutHorizontally { -it / 4 } + fadeOut())
            } else {
                (slideInHorizontally { -it / 4 } + fadeIn()) togetherWith
                    (slideOutHorizontally { it } + fadeOut())
            }
        },
        label = "daily page",
    ) { shown ->
        when (shown) {
            DailyPage.Home -> Home(
                state = state,
                hadith = hadith,
                snackbar = snackbar,
                insets = insets,
                onOpen = { page = it },
                onSettings = { settingsOpen = true },
                onEvent = onEvent,
            )
            DailyPage.Ayah -> AyahScreen(state, snackbar, insets, onBack = { page = DailyPage.Home })
            DailyPage.Hadith -> (hadith as? HadithState.Loaded)?.let {
                HadithScreen(it, state.settings.arabicFontSize, insets, onBack = { page = DailyPage.Home })
            }
        }
    }

    if (settingsOpen) {
        SettingsDialog(
            settings = state.settings,
            translations = translations,
            onEvent = onEvent,
            onDismiss = { settingsOpen = false },
        )
    }
}

/** Both cards, each taking half of whatever height there is, so nothing scrolls. */
@Composable
private fun Home(
    state: DailyState.Loaded,
    hadith: HadithState,
    snackbar: SnackbarHostState,
    insets: PaddingValues,
    onOpen: (DailyPage) -> Unit,
    onSettings: () -> Unit,
    onEvent: (DailyEvent) -> Unit,
) {
    val daily = state.ayah
    val colors = MaterialTheme.wasira
    Column(Modifier.fillMaxSize().background(colors.bg).padding(insets)) {
        TopBar(
            title = stringResource(R.string.app_title),
            color = colors.text,
            navigation = null,
        ) {
            CopyButton(state, snackbar, tint = colors.text)
            IconButton(onClick = onSettings) {
                Icon(
                    painterResource(R.drawable.ic_tune),
                    contentDescription = stringResource(R.string.daily_settings),
                    tint = colors.text,
                    modifier = Modifier.size(18.dp),
                )
            }
        }
        Column(Modifier.weight(1f).padding(start = 16.dp, top = 4.dp, end = 16.dp, bottom = 16.dp)) {
            SectionCard(
                SectionTone.Ayah,
                modifier = Modifier.weight(1f),
                onClick = { onOpen(DailyPage.Ayah) },
                clickLabel = stringResource(R.string.open_ayah),
            ) {
                AyahPreview(
                    ayah = daily.ayah,
                    arabicSize = state.settings.arabicFontSize,
                    translation = daily.translation,
                    translationRtl = daily.translationIsRtl,
                )
            }
            Spacer(Modifier.height(12.dp))
            SectionCard(
                SectionTone.Hadith,
                modifier = Modifier.weight(1f),
                onClick = if (hadith is HadithState.Loaded) ({ onOpen(DailyPage.Hadith) }) else null,
                clickLabel = stringResource(R.string.open_hadith),
            ) {
                HadithPreview(hadith, arabicSize = state.settings.arabicFontSize, onEvent = onEvent)
            }
        }
    }
}

/** Today's ayah in full, on the plain page. */
@Composable
private fun AyahScreen(state: DailyState.Loaded, snackbar: SnackbarHostState, insets: PaddingValues, onBack: () -> Unit) {
    val colors = MaterialTheme.wasira.page()
    val daily = state.ayah
    Column(Modifier.fillMaxSize().background(colors.background).padding(insets)) {
        TopBar(
            title = stringResource(R.string.app_title),
            color = colors.text,
            navigation = { BackButton(onBack, tint = colors.text) },
        ) {
            CopyButton(state, snackbar, tint = colors.text)
        }
        AyahPage(
            ayah = daily.ayah,
            arabicSize = state.settings.arabicFontSize,
            translation = daily.translation,
            translationRtl = daily.translationIsRtl,
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(start = 24.dp, top = 8.dp, end = 24.dp, bottom = 32.dp),
        )
    }
}

/** Today's hadith in full, with its explanation and lessons. */
@Composable
private fun HadithScreen(hadith: HadithState.Loaded, arabicSize: Int, insets: PaddingValues, onBack: () -> Unit) {
    val colors = MaterialTheme.wasira.page()
    Column(Modifier.fillMaxSize().background(colors.background).padding(insets)) {
        TopBar(
            title = stringResource(R.string.app_title),
            color = colors.text,
            navigation = { BackButton(onBack, tint = colors.text) },
        ) {}
        HadithPage(
            hadith.daily.hadith,
            arabicSize = arabicSize,
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(start = 24.dp, top = 8.dp, end = 24.dp, bottom = 32.dp),
        )
    }
}

/** "Wasira" in bold Amiri, with an optional back button before it and actions after. */
@Composable
private fun TopBar(
    title: String,
    color: Color,
    navigation: (@Composable () -> Unit)?,
    actions: @Composable () -> Unit,
) {
    Row(
        Modifier.fillMaxWidth().height(56.dp).padding(start = if (navigation == null) 36.dp else 4.dp, end = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        navigation?.invoke()
        Text(
            title,
            modifier = Modifier.weight(1f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            fontFamily = AmiriLatin,
            fontWeight = FontWeight.Bold,
            fontSize = 20.sp,
            color = color,
        )
        actions()
    }
}

@Composable
private fun BackButton(onBack: () -> Unit, tint: Color) {
    IconButton(onClick = onBack) {
        Icon(
            painterResource(R.drawable.ic_arrow_back),
            contentDescription = stringResource(R.string.back),
            tint = tint,
        )
    }
}

/** Copies the ayah: the Arabic exactly as sent, the translation, and its reference. */
@Composable
private fun CopyButton(state: DailyState.Loaded, snackbar: SnackbarHostState, tint: Color) {
    val daily = state.ayah
    val clipboard = LocalClipboard.current
    val scope = rememberCoroutineScope()
    val copied = stringResource(R.string.copied)
    IconButton(onClick = {
        val text = daily.citation()
        scope.launch {
            clipboard.setClipEntry(ClipEntry(ClipData.newPlainText(daily.ayah.surah.nameEn, text)))
            snackbar.showSnackbar(copied, duration = SnackbarDuration.Short)
        }
    }) {
        Icon(
            painterResource(R.drawable.ic_copy),
            contentDescription = stringResource(R.string.copy_ayah),
            tint = tint,
            modifier = Modifier.size(17.dp),
        )
    }
}
