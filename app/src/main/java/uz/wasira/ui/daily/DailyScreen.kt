package uz.wasira.ui.daily

import android.content.ClipData
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

/** The whole app: one ayah for today, and one hadith under it. Ported from lib/ui/daily/widgets/daily_screen.dart. */
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
        Box(Modifier.fillMaxSize().padding(insets)) {
            when (state) {
                DailyState.Loading -> CircularProgressIndicator(Modifier.align(Alignment.Center))
                DailyState.Unavailable -> Unavailable(
                    onRetry = { onEvent(DailyEvent.Retried) },
                    modifier = Modifier.align(Alignment.Center),
                )
                is DailyState.Loaded -> Loaded(state, translations, hadith, snackbar, onEvent)
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

@Composable
private fun Loaded(
    state: DailyState.Loaded,
    translations: TranslationsState,
    hadith: HadithState,
    snackbar: SnackbarHostState,
    onEvent: (DailyEvent) -> Unit,
) {
    val daily = state.ayah
    val ayah = daily.ayah
    val colors = MaterialTheme.wasira
    val clipboard = LocalClipboard.current
    val scope = rememberCoroutineScope()
    val copied = stringResource(R.string.copied)
    var settingsOpen by rememberSaveable { mutableStateOf(false) }

    Column(Modifier.fillMaxSize()) {
        Row(
            Modifier.fillMaxWidth().padding(start = 36.dp, top = 10.dp, end = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(0.dp),
        ) {
            Text(
                stringResource(R.string.app_title),
                modifier = Modifier.weight(1f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                fontFamily = AmiriLatin,
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp,
                color = colors.text,
            )
            IconButton(onClick = {
                val text = daily.citation()
                scope.launch {
                    clipboard.setClipEntry(ClipEntry(ClipData.newPlainText(ayah.surah.nameEn, text)))
                    snackbar.showSnackbar(copied, duration = SnackbarDuration.Short)
                }
            }) {
                Icon(
                    painterResource(R.drawable.ic_copy),
                    contentDescription = stringResource(R.string.copy_ayah),
                    modifier = Modifier.size(17.dp),
                )
            }
            IconButton(onClick = { settingsOpen = true }) {
                Icon(
                    painterResource(R.drawable.ic_tune),
                    contentDescription = stringResource(R.string.daily_settings),
                    modifier = Modifier.size(18.dp),
                )
            }
        }
        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(start = 16.dp, top = 8.dp, end = 16.dp, bottom = 16.dp),
        ) {
            SectionCard(SectionTone.Accent) {
                AyahView(
                    ayah = ayah,
                    arabicSize = state.settings.arabicFontSize,
                    translation = daily.translation,
                    translationRtl = daily.translationIsRtl,
                    expanded = state.expanded,
                    onExpand = { onEvent(DailyEvent.TranslationExpanded) },
                )
            }
            // Idle means no hadith is coming: no card at all, not an empty one.
            if (hadith != HadithState.Idle) {
                Spacer(Modifier.height(12.dp))
                SectionCard(SectionTone.Outlined) {
                    HadithView(hadith, arabicSize = state.settings.arabicFontSize, onEvent = onEvent)
                }
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
