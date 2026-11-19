package uz.wasira.ui.daily

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uz.wasira.R
import uz.wasira.domain.Hadith
import uz.wasira.ui.components.ArabicText
import uz.wasira.ui.components.SectionHeading
import uz.wasira.ui.theme.wasira

const val HADITH_TRANSLATION_TAG = "hadith_translation"
const val HADITH_EXPLANATION_TAG = "hadith_explanation"

/**
 * Hadith Arabic runs about four times the length of an average ayah, so it sits
 * smaller than the ayah above it while still following the size the user chose.
 */
fun hadithArabicSize(arabicSize: Int): Int = arabicSize * 3 / 4

/** The hadith of the day, under the ayah: Arabic, translation, source and grade, and its explanation on request. */
@Composable
fun HadithView(
    state: HadithState,
    arabicSize: Int,
    onEvent: (DailyEvent) -> Unit,
    modifier: Modifier = Modifier,
) {
    if (state == HadithState.Idle) return
    val colors = MaterialTheme.wasira

    Column(modifier) {
        SectionHeading(stringResource(R.string.hadith_of_the_day))
        Spacer(Modifier.height(8.dp))

        when (state) {
            HadithState.Idle -> Unit
            HadithState.Loading -> CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
            HadithState.Unavailable -> Row {
                Text(
                    stringResource(R.string.hadith_unreachable),
                    modifier = Modifier.weight(1f).padding(top = 8.dp),
                    fontSize = 13.sp,
                    color = colors.muted,
                )
                TextButton(onClick = { onEvent(DailyEvent.HadithRetried) }) {
                    Text(stringResource(R.string.try_again), fontSize = 13.sp)
                }
            }
            is HadithState.Loaded -> Loaded(state, arabicSize, onEvent)
        }
    }
}

@Composable
private fun Loaded(state: HadithState.Loaded, arabicSize: Int, onEvent: (DailyEvent) -> Unit) {
    val hadith = state.daily.hadith
    val colors = MaterialTheme.wasira
    val clamped = !state.expanded && isLong(hadith)

    ArabicText(
        hadith.arabic,
        size = hadithArabicSize(arabicSize),
        maxLines = if (clamped) 4 else Int.MAX_VALUE,
    )
    hadith.translation?.let {
        Spacer(Modifier.height(8.dp))
        SelectionContainer {
            Text(
                it,
                modifier = Modifier.fillMaxWidth().testTag(HADITH_TRANSLATION_TAG),
                maxLines = if (clamped) 3 else Int.MAX_VALUE,
                overflow = if (clamped) TextOverflow.Ellipsis else TextOverflow.Clip,
                style = TextStyle(color = colors.muted, fontSize = 14.sp, lineHeight = (14 * 1.55).sp),
            )
        }
    }
    if (clamped) {
        LinkButton(stringResource(R.string.show_more)) { onEvent(DailyEvent.HadithExpanded) }
    }

    Spacer(Modifier.height(6.dp))
    Text("${hadith.attribution}  ·  ${hadith.grade}", fontSize = 12.sp, color = colors.muted)

    LinkButton(
        stringResource(if (state.explanationOpen) R.string.hide_explanation else R.string.explanation),
    ) { onEvent(DailyEvent.HadithExplanationToggled) }

    if (state.explanationOpen) Explanation(hadith)
}

/** Clamped when either half would bury the rest, as a long ayah translation is. */
private fun isLong(hadith: Hadith): Boolean =
    hadith.arabic.length > CLAMP_THRESHOLD || (hadith.translation?.length ?: 0) > CLAMP_THRESHOLD

@Composable
private fun Explanation(hadith: Hadith) {
    val colors = MaterialTheme.wasira
    val body = TextStyle(color = colors.muted, fontSize = 14.sp, lineHeight = (14 * 1.55).sp)
    SelectionContainer {
        Column(Modifier.testTag(HADITH_EXPLANATION_TAG)) {
            Text(hadith.explanation, style = body)
            if (hadith.hints.isNotEmpty()) {
                Spacer(Modifier.height(12.dp))
                Text(stringResource(R.string.hadith_lessons), fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                for (hint in hadith.hints) {
                    Spacer(Modifier.height(6.dp))
                    Row {
                        Text("•", style = body)
                        Spacer(Modifier.width(8.dp))
                        Text(hint, style = body)
                    }
                }
            }
        }
    }
}

@Composable
private fun LinkButton(label: String, onClick: () -> Unit) {
    TextButton(
        onClick = onClick,
        contentPadding = PaddingValues(0.dp),
        modifier = Modifier.defaultMinSize(minHeight = 32.dp),
    ) {
        Text(label, fontSize = 12.sp, color = MaterialTheme.wasira.accent)
    }
}
