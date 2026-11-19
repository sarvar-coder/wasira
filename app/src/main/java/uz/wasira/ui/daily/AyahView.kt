package uz.wasira.ui.daily

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.PlainTooltip
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TooltipBox
import androidx.compose.material3.TooltipDefaults
import androidx.compose.material3.rememberTooltipState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uz.wasira.R
import uz.wasira.domain.Ayah
import uz.wasira.ui.components.AmiriQuran
import uz.wasira.ui.components.ArabicText
import uz.wasira.ui.theme.wasira

/**
 * Past this many characters a translation is clamped. uz.sodik is a
 * tafsir-translation whose entries reach 2660 characters, which buries the ayah
 * it belongs to.
 */
const val CLAMP_THRESHOLD = 300

const val TRANSLATION_TAG = "translation"

/** One ayah: its number, any sajda mark, the Arabic, and the translation. */
@Composable
fun AyahView(
    ayah: Ayah,
    arabicSize: Int,
    translation: String?,
    translationRtl: Boolean,
    expanded: Boolean,
    onExpand: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = MaterialTheme.wasira
    val long = (translation?.length ?: 0) > CLAMP_THRESHOLD
    val clamped = long && !expanded

    Column(modifier.padding(horizontal = 24.dp, vertical = 18.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            NumberBadge(ayah.numberInSurah)
            if (ayah.sajda) {
                Spacer(Modifier.width(8.dp))
                SajdaMark(obligatory = ayah.sajdaObligatory == true)
            }
        }
        Spacer(Modifier.height(10.dp))
        ArabicText(ayah.text, size = arabicSize)
        if (!translation.isNullOrEmpty()) {
            Spacer(Modifier.height(10.dp))
            // Urdu, Persian and the other RTL translations read right to left
            // whatever the UI language is.
            val direction = if (translationRtl) LayoutDirection.Rtl else LayoutDirection.Ltr
            CompositionLocalProvider(LocalLayoutDirection provides direction) {
                Column(Modifier.fillMaxWidth()) {
                    Text(
                        text = translation,
                        modifier = Modifier.fillMaxWidth().testTag(TRANSLATION_TAG),
                        maxLines = if (clamped) 3 else Int.MAX_VALUE,
                        overflow = if (clamped) TextOverflow.Ellipsis else TextOverflow.Clip,
                        style = TextStyle(
                            color = colors.muted,
                            fontSize = 14.sp,
                            lineHeight = (14 * 1.55).sp,
                            textDirection = if (translationRtl) TextDirection.Rtl else TextDirection.Ltr,
                        ),
                    )
                    if (clamped) {
                        TextButton(
                            onClick = onExpand,
                            contentPadding = PaddingValues(0.dp),
                            modifier = Modifier.defaultMinSize(minHeight = 32.dp),
                        ) {
                            Text(
                                stringResource(R.string.show_more),
                                fontSize = 12.sp,
                                color = colors.accent,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun NumberBadge(number: Int) {
    val accent = MaterialTheme.wasira.accent
    Box(
        Modifier
            .size(30.dp)
            .background(accent.copy(alpha = 0.10f), RoundedCornerShape(8.dp)),
        contentAlignment = Alignment.Center,
    ) {
        Text("$number", color = accent, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
    }
}

/**
 * One of the 15 ayahs of prostration. The API classifies 4 as obligatory and 11
 * as recommended; that split varies by madhhab, so the label reports the
 * classification rather than issuing a ruling.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SajdaMark(obligatory: Boolean) {
    val colors = MaterialTheme.wasira
    val label = stringResource(if (obligatory) R.string.sajda_obligatory_here else R.string.sajda_here)
    TooltipBox(
        positionProvider = TooltipDefaults.rememberPlainTooltipPositionProvider(),
        tooltip = { PlainTooltip { Text(label) } },
        state = rememberTooltipState(),
    ) {
        Text(
            "۩",
            modifier = Modifier.semantics { contentDescription = label },
            fontFamily = AmiriQuran,
            fontSize = 18.sp,
            color = if (obligatory) colors.accent else colors.muted,
        )
    }
}
