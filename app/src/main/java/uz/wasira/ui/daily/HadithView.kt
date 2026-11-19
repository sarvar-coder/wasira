package uz.wasira.ui.daily

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uz.wasira.R
import uz.wasira.domain.Hadith
import uz.wasira.ui.components.AmiriLatin
import uz.wasira.ui.components.ArabicText
import uz.wasira.ui.components.SectionHeading
import uz.wasira.ui.components.SectionTone
import uz.wasira.ui.components.page
import uz.wasira.ui.components.section
import uz.wasira.ui.theme.wasira

const val HADITH_TRANSLATION_TAG = "hadith_translation"
const val HADITH_EXPLANATION_TAG = "hadith_explanation"

/**
 * Hadith Arabic runs about four times the length of an average ayah, so it sits
 * smaller than the ayah while still following the size the user chose.
 */
fun hadithArabicSize(arabicSize: Int): Int = arabicSize * 3 / 4

/**
 * The hadith card on the home page, in every state, so the layout never jumps
 * while it loads. Loaded, it previews as much as the card has room for; tapping
 * opens [HadithPage].
 */
@Composable
fun ColumnScope.HadithPreview(state: HadithState, arabicSize: Int, onEvent: (DailyEvent) -> Unit) {
    val colors = MaterialTheme.wasira.section(SectionTone.Hadith)
    Row(verticalAlignment = Alignment.CenterVertically) {
        SectionHeading(stringResource(R.string.hadith_of_the_day), color = colors.heading)
        if (state is HadithState.Loaded) {
            Spacer(Modifier.weight(1f))
            Icon(
                painterResource(R.drawable.ic_chevron),
                contentDescription = null,
                tint = colors.heading,
                modifier = Modifier.size(22.dp),
            )
        }
    }

    when (state) {
        HadithState.Idle -> Unit
        HadithState.Loading -> Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.dp)
        }
        HadithState.Unavailable -> Column(
            Modifier.weight(1f).fillMaxWidth(),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(stringResource(R.string.hadith_unreachable), fontSize = 13.sp, color = colors.muted)
            TextButton(onClick = { onEvent(DailyEvent.HadithRetried) }) {
                Text(stringResource(R.string.try_again), fontSize = 13.sp)
            }
        }
        is HadithState.Loaded -> {
            val hadith = state.daily.hadith
            Source(hadith, colors.muted)
            Spacer(Modifier.height(8.dp))
            ArabicText(
                hadith.arabic,
                modifier = Modifier.weight(1f).fillMaxWidth(),
                size = hadithArabicSize(arabicSize),
                color = colors.text,
                fillAndCut = true,
                selectable = false,
            )
            hadith.translation?.let {
                Spacer(Modifier.height(6.dp))
                Text(
                    it,
                    modifier = Modifier.fillMaxWidth().testTag(HADITH_TRANSLATION_TAG),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    style = body(colors.muted),
                )
            }
        }
    }
}

/**
 * Everything about today's hadith: the Arabic, the translation, who recorded it
 * and its grade, then the explanation and the lessons, on the plain page.
 * Unpadded and unscrolled.
 */
@Composable
fun HadithPage(hadith: Hadith, arabicSize: Int, modifier: Modifier = Modifier) {
    val colors = MaterialTheme.wasira.page()
    SelectionContainer(modifier) {
        Column {
            SectionHeading(stringResource(R.string.hadith_of_the_day), color = colors.heading)
            Source(hadith, colors.muted)
            Spacer(Modifier.height(14.dp))
            // Already inside this page's SelectionContainer; a second would split the selection.
            ArabicText(hadith.arabic, size = hadithArabicSize(arabicSize), color = colors.text, selectable = false)
            hadith.translation?.let {
                Spacer(Modifier.height(12.dp))
                Text(
                    it,
                    modifier = Modifier.fillMaxWidth().testTag(HADITH_TRANSLATION_TAG),
                    style = body(colors.text),
                )
            }

            Column(Modifier.padding(top = 24.dp).testTag(HADITH_EXPLANATION_TAG)) {
                SubHeading(stringResource(R.string.explanation), colors.heading)
                Spacer(Modifier.height(6.dp))
                Text(hadith.explanation, style = body(colors.muted))
                if (hadith.hints.isNotEmpty()) {
                    Spacer(Modifier.height(20.dp))
                    SubHeading(stringResource(R.string.hadith_lessons), colors.heading)
                    for (hint in hadith.hints) {
                        Spacer(Modifier.height(8.dp))
                        Row {
                            Text("•", style = body(colors.heading))
                            Spacer(Modifier.width(10.dp))
                            Text(hint, style = body(colors.muted))
                        }
                    }
                }
            }
        }
    }
}

/** "Narrated by At-Tirmidhi  ·  Authentic" */
@Composable
private fun Source(hadith: Hadith, color: Color) {
    Text(
        "${hadith.attribution}  ·  ${hadith.grade}",
        fontSize = 12.sp,
        color = color,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
    )
}

@Composable
private fun SubHeading(text: String, color: Color) {
    Text(
        text,
        fontFamily = AmiriLatin,
        fontWeight = FontWeight.Bold,
        fontSize = 16.sp,
        color = color,
    )
}

private fun body(color: Color) = TextStyle(color = color, fontSize = 14.sp, lineHeight = (14 * 1.6).sp)
