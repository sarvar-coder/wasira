package uz.wasira.ui.daily

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.PlainTooltip
import androidx.compose.material3.Text
import androidx.compose.material3.TooltipBox
import androidx.compose.material3.TooltipDefaults
import androidx.compose.material3.rememberTooltipState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uz.wasira.R
import uz.wasira.domain.Ayah
import uz.wasira.domain.ayahReference
import uz.wasira.ui.components.AmiriQuran
import uz.wasira.ui.components.ArabicText
import uz.wasira.ui.components.SectionColors
import uz.wasira.ui.components.SectionHeading
import uz.wasira.ui.components.SectionTone
import uz.wasira.ui.components.page
import uz.wasira.ui.components.section
import uz.wasira.ui.theme.wasira

const val TRANSLATION_TAG = "translation"

/** The ayah's place under its heading: "Al-Baqara  ·  2:255". */
fun ayahLabel(surahName: String, surah: Int, numberInSurah: Int): String =
    "$surahName  ·  ${ayahReference(surah, numberInSurah)}"

/**
 * The ayah card on the home page: heading, reference, as much of the Arabic as
 * the card has room for, and the start of the translation. Tapping the card
 * opens [AyahPage] with all of it.
 */
@Composable
fun ColumnScope.AyahPreview(ayah: Ayah, arabicSize: Int, translation: String?, translationRtl: Boolean) {
    val colors = MaterialTheme.wasira.section(SectionTone.Ayah)
    AyahHeading(ayah, opens = true, colors)
    Spacer(Modifier.height(8.dp))
    ArabicText(
        ayah.text,
        modifier = Modifier.weight(1f).fillMaxWidth(),
        size = arabicSize,
        color = colors.text,
        fillAndCut = true,
        selectable = false,
    )
    if (!translation.isNullOrEmpty()) {
        Spacer(Modifier.height(6.dp))
        Translation(translation, translationRtl, colors.muted, maxLines = 2)
    }
}

/** Everything about today's ayah, on the plain page: the full Arabic and the full translation. Unpadded and unscrolled. */
@Composable
fun AyahPage(
    ayah: Ayah,
    arabicSize: Int,
    translation: String?,
    translationRtl: Boolean,
    modifier: Modifier = Modifier,
) {
    val colors = MaterialTheme.wasira.page()
    Column(modifier) {
        AyahHeading(ayah, opens = false, colors)
        Spacer(Modifier.height(14.dp))
        ArabicText(ayah.text, size = arabicSize, color = colors.text)
        if (!translation.isNullOrEmpty()) {
            Spacer(Modifier.height(14.dp))
            Translation(translation, translationRtl, colors.muted, maxLines = Int.MAX_VALUE)
        }
    }
}

/** "Ayah of the day", any sajda mark, the reference, and on the card a mark that it opens. */
@Composable
private fun AyahHeading(ayah: Ayah, opens: Boolean, colors: SectionColors) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        SectionHeading(stringResource(R.string.ayah_of_the_day), color = colors.heading)
        if (ayah.sajda) {
            Spacer(Modifier.width(8.dp))
            SajdaMark(obligatory = ayah.sajdaObligatory == true, colors)
        }
        if (opens) {
            Spacer(Modifier.weight(1f))
            Icon(
                painterResource(R.drawable.ic_chevron),
                contentDescription = null,
                tint = colors.heading,
                modifier = Modifier.size(22.dp),
            )
        }
    }
    Text(
        ayahLabel(ayah.surah.nameEn, ayah.surah.number, ayah.numberInSurah),
        fontSize = 12.sp,
        color = colors.muted,
    )
}

/** Urdu, Persian and the other RTL translations read right to left whatever the UI language is. */
@Composable
private fun Translation(text: String, rtl: Boolean, color: Color, maxLines: Int) {
    val direction = if (rtl) LayoutDirection.Rtl else LayoutDirection.Ltr
    CompositionLocalProvider(LocalLayoutDirection provides direction) {
        Text(
            text = text,
            modifier = Modifier.fillMaxWidth().testTag(TRANSLATION_TAG),
            maxLines = maxLines,
            overflow = if (maxLines == Int.MAX_VALUE) TextOverflow.Clip else TextOverflow.Ellipsis,
            style = TextStyle(
                color = color,
                fontSize = 14.sp,
                lineHeight = (14 * 1.55).sp,
                textDirection = if (rtl) TextDirection.Rtl else TextDirection.Ltr,
            ),
        )
    }
}

/**
 * One of the 15 ayahs of prostration. The API classifies 4 as obligatory and 11
 * as recommended; that split varies by madhhab, so the label reports the
 * classification rather than issuing a ruling.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SajdaMark(obligatory: Boolean, colors: SectionColors) {
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
            color = if (obligatory) colors.heading else colors.muted,
        )
    }
}
