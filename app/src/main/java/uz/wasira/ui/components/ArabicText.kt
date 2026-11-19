package uz.wasira.ui.components

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.sp
import uz.wasira.R

/**
 * Amiri Quran, locked by docs/adr/0002. Changing it means re-recording the
 * goldens: a different face can silently lack a rare Quranic mark.
 */
val AmiriQuran = FontFamily(Font(R.font.amiri_quran))

/** Uthmani tashkeel collides below a line height of about 2.0. */
const val ARABIC_LINE_HEIGHT = 2.0f

/**
 * Quranic Arabic, and the Arabic of the daily hadith. Always right-to-left regardless of the app's UI language.
 * The string is rendered exactly as given; nothing here transforms it.
 */
@Composable
fun ArabicText(
    text: String,
    modifier: Modifier = Modifier,
    size: Int = 30,
    color: Color = Color.Unspecified,
    align: TextAlign = TextAlign.Right,
    /** Lines shown before the rest is cut with an ellipsis. Unlimited for the ayah. */
    maxLines: Int = Int.MAX_VALUE,
) {
    val resolved = if (color == Color.Unspecified) MaterialTheme.colorScheme.onSurface else color
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
        SelectionContainer(modifier) {
            Text(
                text = text,
                modifier = Modifier.fillMaxWidth(),
                maxLines = maxLines,
                overflow = if (maxLines == Int.MAX_VALUE) TextOverflow.Clip else TextOverflow.Ellipsis,
                style = TextStyle(
                    fontFamily = AmiriQuran,
                    fontSize = size.sp,
                    lineHeight = (size * ARABIC_LINE_HEIGHT).sp,
                    color = resolved,
                    textAlign = align,
                    textDirection = TextDirection.Rtl,
                    lineHeightStyle = LineHeightStyle(
                        alignment = LineHeightStyle.Alignment.Center,
                        trim = LineHeightStyle.Trim.None,
                    ),
                ),
            )
        }
    }
}
