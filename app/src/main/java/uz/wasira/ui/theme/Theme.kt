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
 * Warm neutrals rather than blue-greys: parchment, not office software. The
 * text is the interface, so the surface stays quiet. Ported from
 * lib/ui/core/themes/tokens.dart.
 */
@Immutable
data class WasiraColors(
    val bg: Color,
    val surface: Color,
    val text: Color,
    val muted: Color,
    val accent: Color,
    val divider: Color,
) {
    companion object {
        val Light = WasiraColors(
            bg = Color(0xFFFAF8F4),
            surface = Color(0xFFFFFFFF),
            text = Color(0xFF1C1917),
            muted = Color(0xFF78716C),
            accent = Color(0xFF0F5132),
            divider = Color(0xFFE7E5E4),
        )
        val Dark = WasiraColors(
            bg = Color(0xFF14130F),
            surface = Color(0xFF1E1C18),
            text = Color(0xFFF5F3EF),
            muted = Color(0xFFA8A29E),
            accent = Color(0xFF5EAD8A),
            divider = Color(0xFF2C2A26),
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
