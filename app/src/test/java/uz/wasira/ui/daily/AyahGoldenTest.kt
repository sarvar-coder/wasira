package uz.wasira.ui.daily

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import uz.wasira.ui.components.SectionCard
import uz.wasira.ui.components.SectionTone
import uz.wasira.ui.fixture
import uz.wasira.ui.theme.WasiraTheme
import uz.wasira.ui.theme.wasira

/**
 * AyahView rendered from live API responses (fixtures/golden_*.json). A changed
 * font, line height or a Quranic mark gone missing shows up here as a diff.
 * Record with `./gradlew recordRoborazziDebug`, check with `verifyRoborazziDebug`.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w411dp-h891dp-xxhdpi")
class AyahGoldenTest {
    private fun golden(name: String, dark: Boolean = false) {
        val daily = fixture(name)
        captureRoboImage("src/test/snapshots/ayah_${name.removePrefix("golden_")}${if (dark) "_dark" else ""}.png") {
            WasiraTheme(darkTheme = dark) {
                Box(Modifier.width(411.dp).background(MaterialTheme.wasira.bg).padding(16.dp)) {
                    // The card it sits in on the daily screen.
                    SectionCard(SectionTone.Accent) {
                        AyahView(
                            ayah = daily.ayah,
                            arabicSize = 30,
                            translation = daily.translation,
                            translationRtl = daily.translationIsRtl,
                            expanded = false,
                            onExpand = {},
                        )
                    }
                }
            }
        }
    }

    /** Ayat al-Kursi: long, dense tashkeel. */
    @Test fun ayatAlKursi() = golden("golden_2_255")

    /** The Bismillah as ayah 1 of al-Fatiha, BOM removed. */
    @Test fun fatiha1() = golden("golden_1_1")

    /** An obligatory sajda: the accent ۩ by the heading, and the ۩ in the text itself. */
    @Test fun sajda() = golden("golden_32_15")

    /** The Bismillah inside Sulayman's letter: genuine ayah content, never split. */
    @Test fun naml30() = golden("golden_27_30")

    @Test fun ayatAlKursiDark() = golden("golden_2_255", dark = true)
}
