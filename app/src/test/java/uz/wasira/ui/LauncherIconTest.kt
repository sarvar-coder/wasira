package uz.wasira.ui

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.drawable.AdaptiveIconDrawable
import org.robolectric.RuntimeEnvironment
import com.github.takahirom.roborazzi.captureRoboImage
import android.content.Context
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import uz.wasira.R

/**
 * Renders the adaptive icon so the SVG conversion can be looked at, and checks
 * the artwork stays inside the 66dp safe zone: nothing is drawn outside a
 * 33dp-radius circle about the centre of the 108dp foreground.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "mdpi")
class LauncherIconTest {
    private val context: Context = RuntimeEnvironment.getApplication()
    private val size = 432 // 108dp at 4px per dp

    private fun render(draw: (Canvas) -> Unit): Bitmap =
        Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888).also { draw(Canvas(it)) }

    @Test fun adaptiveIcon() {
        val icon = context.getDrawable(R.mipmap.ic_launcher) as AdaptiveIconDrawable
        icon.setBounds(0, 0, size, size)
        render { icon.draw(it) }.captureRoboImage("src/test/snapshots/launcher_icon.png")
    }

    @Test fun foregroundWithSafeZone() {
        val fg = context.getDrawable(R.drawable.ic_launcher_foreground)!!
        fg.setBounds(0, 0, size, size)
        val bitmap = render { c ->
            c.drawColor(context.getColor(R.color.ic_launcher_background))
            fg.draw(c)
            c.drawCircle(size / 2f, size / 2f, 33f * 4, Paint().apply {
                style = Paint.Style.STROKE
                color = Color.RED
                strokeWidth = 1f
            })
        }
        bitmap.captureRoboImage("src/test/snapshots/launcher_foreground_safe_zone.png")
    }

    @Test fun monochrome() {
        val mono = context.getDrawable(R.drawable.ic_launcher_monochrome)!!
        mono.setBounds(0, 0, size, size)
        render { c -> c.drawColor(Color.WHITE); mono.draw(c) }
            .captureRoboImage("src/test/snapshots/launcher_monochrome.png")
    }

    @Test fun artworkStaysInsideTheSafeZone() {
        listOf(R.drawable.ic_launcher_foreground, R.drawable.ic_launcher_monochrome).forEach { id ->
            val d = context.getDrawable(id)!!
            d.setBounds(0, 0, size, size)
            val bitmap = render { d.draw(it) }
            val c = size / 2.0
            val r = 33.0 * 4 + 1.5 // antialiasing
            var outside = 0
            for (y in 0 until size) for (x in 0 until size) {
                val alpha = Color.alpha(bitmap.getPixel(x, y))
                if (alpha > 8 && Math.hypot(x + 0.5 - c, y + 0.5 - c) > r) outside++
            }
            assertEquals("pixels outside the safe zone in ${context.resources.getResourceEntryName(id)}", 0, outside)
        }
    }
}
