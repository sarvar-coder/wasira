package uz.wasira.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uz.wasira.ui.theme.wasira

private val CardShape = RoundedCornerShape(16.dp)

/** How a [SectionCard] sets itself apart from the page. */
enum class SectionTone {
    /** The ayah: a faint wash of the accent, so it reads first. */
    Accent,

    /** The hadith: plain surface with a hairline border, quieter than the ayah. */
    Outlined,
}

/** One section of the daily screen: the ayah, or the hadith. Pads its content by 20dp. */
@Composable
fun SectionCard(
    tone: SectionTone,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    val colors = MaterialTheme.wasira
    val background = when (tone) {
        SectionTone.Accent -> colors.accent.copy(alpha = 0.06f).compositeOver(colors.surface)
        SectionTone.Outlined -> colors.surface
    }
    val border = when (tone) {
        SectionTone.Accent -> null
        SectionTone.Outlined -> BorderStroke(1.dp, colors.divider)
    }
    Column(
        modifier
            .fillMaxWidth()
            .background(background, CardShape)
            .then(if (border != null) Modifier.border(border, CardShape) else Modifier)
            .padding(20.dp),
        content = content,
    )
}

/** A section's title, "Ayah of the day" or "Hadith of the day": bold Amiri in the accent colour. */
@Composable
fun SectionHeading(text: String, modifier: Modifier = Modifier) {
    Text(
        text,
        modifier = modifier.semantics { heading() },
        fontFamily = AmiriLatin,
        fontWeight = FontWeight.Bold,
        fontSize = 17.sp,
        color = MaterialTheme.wasira.accent,
    )
}
