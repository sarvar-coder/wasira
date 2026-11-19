package uz.wasira.ui.daily

import android.content.Context
import android.os.Build
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import uz.wasira.R
import uz.wasira.data.Settings
import uz.wasira.data.SettingsRepository
import uz.wasira.ui.components.TranslationList
import uz.wasira.ui.theme.wasira

private val ARABIC_SIZES = SettingsRepository.ARABIC_SIZES

/**
 * Arabic size, the translation, and the five reminder times. Nothing else is
 * configurable, because nothing else exists.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun SettingsDialog(
    settings: Settings,
    translations: TranslationsState,
    onEvent: (DailyEvent) -> Unit,
    onDismiss: () -> Unit,
) {
    val muted = MaterialTheme.wasira.muted
    var picking by rememberSaveable { mutableStateOf(false) }
    var aboutOpen by rememberSaveable { mutableStateOf(false) }
    var editingSlot by rememberSaveable { mutableIntStateOf(-1) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.daily_settings), fontSize = 16.sp) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                Text(stringResource(R.string.arabic_text_size), fontSize = 12.sp, color = muted)
                Spacer(Modifier.height(8.dp))
                SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                    ARABIC_SIZES.forEachIndexed { i, size ->
                        SegmentedButton(
                            selected = settings.arabicFontSize == size,
                            onClick = { onEvent(DailyEvent.ArabicSizeChanged(size)) },
                            shape = SegmentedButtonDefaults.itemShape(i, ARABIC_SIZES.size),
                            icon = {},
                        ) { Text("$size") }
                    }
                }
                Spacer(Modifier.height(20.dp))
                Text(stringResource(R.string.translation), fontSize = 12.sp, color = muted)
                // Changeable here, not only at first launch.
                TextButton(onClick = {
                    onEvent(DailyEvent.TranslationsRequested)
                    picking = true
                }) { Text(settings.translationLabel) }
                Spacer(Modifier.height(20.dp))
                Text(stringResource(R.string.reminders), fontSize = 12.sp, color = muted)
                // One ayah, five nudges.
                FlowRow {
                    settings.reminderTimes.forEachIndexed { slot, minutes ->
                        TextButton(onClick = { editingSlot = slot }) {
                            Text(formatMinutes(LocalContext.current, minutes))
                        }
                    }
                }
            }
        },
        dismissButton = {
            TextButton(onClick = { aboutOpen = true }) { Text(stringResource(R.string.about)) }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(android.R.string.ok)) }
        },
    )

    if (picking) {
        TranslationPicker(
            selected = settings.translationEdition,
            translations = translations,
            onPicked = { id, name ->
                onEvent(DailyEvent.TranslationChanged(id, name))
                picking = false
                onDismiss()
            },
            onDismiss = { picking = false },
        )
    }
    if (editingSlot in settings.reminderTimes.indices) {
        val slot = editingSlot
        ReminderTimePicker(
            minutes = settings.reminderTimes[slot],
            onPicked = {
                onEvent(DailyEvent.ReminderTimeChanged(slot, it))
                editingSlot = -1
            },
            onDismiss = { editingSlot = -1 },
        )
    }
    if (aboutOpen) {
        AboutDialog(translationName = settings.translationName, onDismiss = { aboutOpen = false })
    }
}

fun formatMinutes(context: Context, minutes: Int): String {
    val pattern = if (android.text.format.DateFormat.is24HourFormat(context)) "HH:mm" else "h:mm a"
    val locale = context.resources.configuration.locales[0]
    return LocalTime.of(minutes / 60, minutes % 60).format(DateTimeFormatter.ofPattern(pattern, locale))
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReminderTimePicker(minutes: Int, onPicked: (Int) -> Unit, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val state = rememberTimePickerState(
        initialHour = minutes / 60,
        initialMinute = minutes % 60,
        is24Hour = android.text.format.DateFormat.is24HourFormat(context),
    )
    AlertDialog(
        onDismissRequest = onDismiss,
        text = { TimePicker(state) },
        confirmButton = {
            TextButton(onClick = { onPicked(state.hour * 60 + state.minute) }) {
                Text(stringResource(android.R.string.ok))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(android.R.string.cancel)) }
        },
    )
}

/** The full list of translations, fetched when asked for rather than held. */
@Composable
private fun TranslationPicker(
    selected: String?,
    translations: TranslationsState,
    onPicked: (String, String) -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.choose_translation), fontSize = 16.sp) },
        text = {
            Box(Modifier.fillMaxWidth().height(420.dp), contentAlignment = Alignment.Center) {
                when (translations) {
                    TranslationsState.Idle, TranslationsState.Loading -> CircularProgressIndicator()
                    TranslationsState.Failed -> Text(
                        stringResource(R.string.service_unreachable),
                        color = MaterialTheme.wasira.muted,
                    )
                    is TranslationsState.Loaded -> TranslationList(
                        editions = translations.editions,
                        selected = selected,
                        onSelected = { onPicked(it.identifier, it.englishName) },
                    )
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(android.R.string.cancel)) }
        },
    )
}

/** Where the words come from, and the licence that has to travel with the font. */
@Composable
private fun AboutDialog(translationName: String?, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val muted = MaterialTheme.wasira.muted
    val version = rememberSaveable { appVersion(context) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.app_title), fontSize = 16.sp) },
        text = {
            SelectionContainer {
                Column(Modifier.verticalScroll(rememberScrollState())) {
                    Text("${stringResource(R.string.version)} $version", fontSize = 12.sp, color = muted)
                    Spacer(Modifier.height(16.dp))
                    Text(stringResource(R.string.text_from, AboutConstants.QURAN_SOURCE))
                    Text(AboutConstants.QURAN_SOURCE_URL, fontSize = 12.sp, color = muted)
                    if (translationName != null) {
                        Spacer(Modifier.height(4.dp))
                        Text(
                            "${stringResource(R.string.translation)}: $translationName",
                            fontSize = 12.sp,
                            color = muted,
                        )
                    }
                    Spacer(Modifier.height(16.dp))
                    Text(AboutConstants.FONT_NAME)
                    Text(AboutConstants.FONT_COPYRIGHT, fontSize = 12.sp, color = muted)
                    Text(AboutConstants.FONT_LICENCE, fontSize = 12.sp, color = muted)
                    Text(AboutConstants.FONT_LICENCE_URL, fontSize = 12.sp, color = muted)
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(android.R.string.ok)) }
        },
    )
}

private fun appVersion(context: Context): String = try {
    val pm = context.packageManager
    val info = if (Build.VERSION.SDK_INT >= 33) {
        pm.getPackageInfo(context.packageName, android.content.pm.PackageManager.PackageInfoFlags.of(0))
    } else {
        @Suppress("DEPRECATION")
        pm.getPackageInfo(context.packageName, 0)
    }
    info.versionName.orEmpty()
} catch (_: Exception) {
    ""
}
