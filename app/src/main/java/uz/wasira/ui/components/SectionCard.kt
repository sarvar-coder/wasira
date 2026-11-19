package uz.wasira.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uz.wasira.ui.theme.WasiraColors
import uz.wasira.ui.theme.wasira

private val CardShape = RoundedCornerShape(20.dp)

/** Which of the two sections a [SectionCard] holds; each has its own colours. */
enum class SectionTone {
    /** The ayah: the deeper green, so it reads first. */
    Ayah,

    /** The hadith: a lighter green, so the two read as a pair but apart. */
    Hadith,
}

/** The colours used inside a card of [tone]. [heading] is the text colour: no gold, no tint. */
data class SectionColors(val background: Color, val text: Color, val muted: Color, val heading: Color)

fun WasiraColors.section(tone: SectionTone): SectionColors = when (tone) {
    SectionTone.Ayah -> SectionColors(ayahCard, onAyahCard, ayahCardMuted, onAyahCard)
    SectionTone.Hadith -> SectionColors(hadithCard, onAyahCard, ayahCardMuted, onAyahCard)
}

/** The colours of a page a card opens: the neutral page, never the green. */
fun WasiraColors.page(): SectionColors = SectionColors(bg, text, muted, text)

/**
 * One section of the daily screen: the ayah, or the hadith. Pads its content by
 * 20dp. With [onClick] the whole card is one tap target, labelled [clickLabel].
 */
@Composable
fun SectionCard(
    tone: SectionTone,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    clickLabel: String? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val colors = MaterialTheme.wasira
    val section = colors.section(tone)
    Column(
        modifier
            .fillMaxWidth()
            .clip(CardShape)
            .background(section.background)
            .then(
                if (onClick != null) {
                    Modifier.clickable(onClickLabel = clickLabel, role = Role.Button, onClick = onClick)
                } else {
                    Modifier
                },
            )
            .padding(20.dp),
        content = content,
    )
}

/** A section's title, "Ayah of the day" or "Hadith of the day": bold Amiri. */
@Composable
fun SectionHeading(text: String, color: Color, modifier: Modifier = Modifier) {
    Text(
        text,
        modifier = modifier.semantics { heading() },
        fontFamily = AmiriLatin,
        fontWeight = FontWeight.Bold,
        fontSize = 18.sp,
        color = color,
    )
}
