package uz.wasira.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/**
 * Two dark-green cards on a neutral page: cream by day, charcoal by night. The
 * green is only ever a card, never the page. The ayah card is the deeper green,
 * the hadith card a lighter one. Headings are the text colour, set apart by
 * weight and face alone. Every text-on-background pair here clears WCAG AA (4.5:1).
 */
@Immutable
data class WasiraColors(
    val bg: Color,
    /** Dialogs and the hadith card. */
    val surface: Color,
    val text: Color,
    val muted: Color,
    /** Buttons and links. */
    val accent: Color,
    /** Hairlines and the hadith card's border. */
    val divider: Color,
    val ayahCard: Color,
    val onAyahCard: Color,
    val ayahCardMuted: Color,
    val hadithCard: Color,
) {
    companion object {
        val Light = WasiraColors(
            bg = Color(0xFFF5F0E6),
            surface = Color(0xFFFFFCF5),
            text = Color(0xFF1A2620),
            muted = Color(0xFF6B6A5E),
            accent = Color(0xFF0E3B2E),
            divider = Color(0xFFE3D9C3),
            ayahCard = Color(0xFF0E3B2E),
            onAyahCard = Color(0xFFF5F0E6),
            ayahCardMuted = Color(0xFFCFE0D6),
            hadithCard = Color(0xFF1A4A3B),
        )
        val Dark = WasiraColors(
            bg = Color(0xFF141414),
            surface = Color(0xFF1E1E1E),
            text = Color(0xFFECE8E1),
            muted = Color(0xFFA3A3A0),
            accent = Color(0xFF7FC4A0),
            divider = Color(0xFF2C2C2A),
            ayahCard = Color(0xFF123D30),
            onAyahCard = Color(0xFFF5F0E6),
            ayahCardMuted = Color(0xFFBFD3C8),
            hadithCard = Color(0xFF1A4A3B),
        )
    }
}

val LocalWasiraColors = staticCompositionLocalOf { WasiraColors.Light }

/** The tokens in effect: `MaterialTheme.wasira.muted`. */
val MaterialTheme.wasira: WasiraColors
    @Composable @ReadOnlyComposable get() = LocalWasiraColors.current

/** No manual toggle: the app follows the system appearance. */
@Composable
fun WasiraTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val c = if (darkTheme) WasiraColors.Dark else WasiraColors.Light
    val scheme = if (darkTheme) {
        darkColorScheme(
            primary = c.accent,
            onPrimary = c.bg,
            secondaryContainer = c.accent.copy(alpha = 0.22f),
            onSecondaryContainer = c.text,
            background = c.bg,
            onBackground = c.text,
            surface = c.bg,
            onSurface = c.text,
            surfaceContainerHigh = c.surface,
            surfaceContainerHighest = c.surface,
            surfaceContainer = c.surface,
            onSurfaceVariant = c.muted,
            outline = c.muted,
            outlineVariant = c.divider,
        )
    } else {
        lightColorScheme(
            primary = c.accent,
            onPrimary = c.surface,
            secondaryContainer = c.accent.copy(alpha = 0.12f),
            onSecondaryContainer = c.text,
            background = c.bg,
            onBackground = c.text,
            surface = c.bg,
            onSurface = c.text,
            surfaceContainerHigh = c.surface,
            surfaceContainerHighest = c.surface,
            surfaceContainer = c.surface,
            onSurfaceVariant = c.muted,
            outline = c.muted,
            outlineVariant = c.divider,
        )
    }
    CompositionLocalProvider(LocalWasiraColors provides c) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}
