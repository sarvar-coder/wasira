package uz.wasira.ui.daily

import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.activity.ComponentActivity
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.style.ResolvedTextDirection
import androidx.compose.ui.unit.LayoutDirection
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import uz.wasira.data.Settings
import uz.wasira.domain.DailyAyah
import uz.wasira.domain.DailyHadith
import uz.wasira.domain.Hadith
import uz.wasira.ui.FakeApi
import uz.wasira.ui.FakeDaily
import uz.wasira.ui.FakeHadith
import uz.wasira.ui.FakeReminders
import uz.wasira.ui.FakeSettings
import uz.wasira.ui.HADITH
import uz.wasira.ui.fixture
import uz.wasira.ui.theme.WasiraTheme

@RunWith(RobolectricTestRunner::class)
class DailyScreenTest {
    @get:Rule val compose = createAndroidComposeRule<ComponentActivity>()

    private val settings = Settings("en.sahih", "Saheeh International", 30, listOf(480, 660, 840, 1020, 1200))

    private fun show(
        ayah: DailyAyah,
        hadith: HadithState = HadithState.Idle,
        onEvent: (DailyEvent) -> Unit = {},
    ) {
        compose.setContent {
            WasiraTheme(darkTheme = false) {
                DailyScreen(DailyState.Loaded(ayah, settings), TranslationsState.Idle, onEvent, hadith = hadith)
            }
        }
    }

    @Test fun `the top bar names the app`() {
        show(fixture("golden_2_255"))
        compose.onNodeWithText("Wasira").assertExists()
    }

    @Test fun `the ayah card is headed and names the surah and cites surah colon ayah`() {
        show(fixture("golden_2_255"))
        compose.onNodeWithText("Ayah of the day").assertExists()
        compose.onNodeWithText("Al-Baqara  ·  2:255").assertExists()
    }

    @Test fun `the hadith card holds its place while the hadith is idle`() {
        show(fixture("golden_2_255"), hadith = HadithState.Idle)
        compose.onNodeWithText("Hadith of the day").assertExists()
    }

    @Test fun `the hadith card is headed while it loads`() {
        show(fixture("golden_2_255"), hadith = HadithState.Loading)
        compose.onNodeWithText("Hadith of the day").assertExists()
    }

    @Test fun `unavailable shows try again, and retrying refetches`() {
        val daily = FakeDaily(clock = { LocalDateTime.now() }).apply { failures = 1 }
        val vm = DailyViewModel(daily, FakeSettings(settings), FakeApi(), FakeReminders(), FakeHadith())
        compose.setContent {
            WasiraTheme(darkTheme = false) {
                val state by vm.state.collectAsState()
                DailyScreen(state, TranslationsState.Idle, vm::onEvent)
            }
        }
        compose.onNodeWithText("Could not reach the Quran service").assertExists()
        compose.onNodeWithText("Try again").performClick()
        compose.waitForIdle()
        assertEquals(2, daily.calls)
        compose.onNodeWithText("Al-Baqara  ·  2:255").assertExists()
        compose.onAllNodesWithText("Try again").assertCountEquals(0)
    }

    @Test fun `both cards fit the screen with nothing to scroll`() {
        show(fixture("golden_2_255"), hadith = loadedHadith())
        compose.onNodeWithText("Ayah of the day").assertIsDisplayed()
        compose.onNodeWithText("Hadith of the day").assertIsDisplayed()
        compose.onNodeWithText("Narrated by At-Tirmidhi  ·  Authentic").assertIsDisplayed()
    }

    @Test fun `the ayah card previews and opens the full ayah, and back returns home`() {
        val long = fixture("golden_1_1").copy(translation = "a ".repeat(400))
        show(long, hadith = loadedHadith())
        // Robolectric without native graphics does not wrap text, so the line
        // limit is what is checked: two on the card, none on the page.
        assertEquals(2, translationLayout().layoutInput.maxLines)

        compose.onNode(opens("Open ayah")).performClick()
        compose.waitForIdle()
        assertEquals(Int.MAX_VALUE, translationLayout().layoutInput.maxLines)
        compose.onAllNodesWithText("Hadith of the day").assertCountEquals(0)

        compose.onNodeWithContentDescription("Back").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Hadith of the day").assertExists()
    }

    @Test fun `system back on a page returns home`() {
        show(fixture("golden_1_1"), hadith = loadedHadith())
        compose.onNode(opens("Open hadith")).performClick()
        compose.waitForIdle()
        compose.onNodeWithText(HADITH.explanation).assertExists()

        compose.runOnUiThread { compose.activity.onBackPressedDispatcher.onBackPressed() }
        compose.waitForIdle()
        compose.onAllNodesWithText(HADITH.explanation).assertCountEquals(0)
        compose.onNodeWithText("Ayah of the day").assertExists()
    }

    @Test fun `the hadith page shows the explanation and the lessons`() {
        show(fixture("golden_1_1"), hadith = loadedHadith())
        compose.onAllNodesWithText(HADITH.explanation).assertCountEquals(0)
        compose.onNode(opens("Open hadith")).performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Explanation").assertExists()
        compose.onNodeWithText(HADITH.explanation).assertExists()
        compose.onNodeWithText("Lessons").assertExists()
        compose.onNodeWithText(HADITH.hints.single()).assertExists()
    }

    @Test fun `a hadith still loading cannot be opened`() {
        show(fixture("golden_1_1"), hadith = HadithState.Loading)
        compose.onAllNodes(opens("Open hadith")).assertCountEquals(0)
    }

    @Test fun `urdu translation is laid out right to left`() {
        show(urdu())
        val layout = translationLayout()
        assertEquals(LayoutDirection.Rtl, layout.layoutInput.layoutDirection)
        assertEquals(ResolvedTextDirection.Rtl, layout.getParagraphDirection(0))
    }

    @Test fun `english translation is laid out left to right`() {
        show(fixture("golden_2_255"))
        val layout = translationLayout()
        assertEquals(LayoutDirection.Ltr, layout.layoutInput.layoutDirection)
        assertEquals(ResolvedTextDirection.Ltr, layout.getParagraphDirection(0))
    }

    /**
     * A card by the label of its tap action. The label is on the action, not a
     * content description, so a screen reader still reads the card's own text.
     */
    private fun opens(label: String) = SemanticsMatcher("opens $label") {
        it.config.getOrElseNullable(SemanticsActions.OnClick) { null }?.label == label
    }

    private fun translationLayout(): TextLayoutResult {
        val results = mutableListOf<TextLayoutResult>()
        compose.onNodeWithTag(TRANSLATION_TAG, useUnmergedTree = true)
            .fetchSemanticsNode().config[SemanticsActions.GetTextLayoutResult].action!!.invoke(results)
        return results.single()
    }

    /** 1:1 with ur.jalandhry, as the live API sends it. */
    private fun urdu() = fixture("golden_1_1").copy(
        edition = "ur.jalandhry",
        translation = "شروع الله کا نام لے کر جو بڑا مہربان نہایت رحم والا ہے",
        translationDirection = "rtl",
    )

    private fun loadedHadith(hadith: Hadith = HADITH) = HadithState.Loaded(DailyHadith("2026-11-19", hadith))

    @Test fun `the hadith card shows its source and grade`() {
        show(fixture("golden_1_1"), hadith = loadedHadith())
        compose.onNodeWithText(HADITH.arabic).assertExists()
        compose.onNodeWithText(HADITH.translation!!).assertExists()
        compose.onNodeWithText("Narrated by At-Tirmidhi  ·  Authentic").assertExists()
    }

    @Test fun `an arabic hadith has no translation line`() {
        show(fixture("golden_1_1"), hadith = loadedHadith(HADITH.copy(language = "ar", translation = null)))
        compose.onNodeWithText(HADITH.arabic).assertExists()
        compose.onAllNodesWithTag(HADITH_TRANSLATION_TAG).assertCountEquals(0)
    }

    @Test fun `hadith unavailable - the ayah stays and the hadith card offers a retry`() {
        val events = mutableListOf<DailyEvent>()
        show(fixture("golden_1_1"), hadith = HadithState.Unavailable, onEvent = { events += it })
        compose.onNodeWithText("Al-Faatiha  ·  1:1").assertExists()
        compose.onNodeWithText("Could not reach the hadith service").assertIsDisplayed()
        compose.onNodeWithText("Try again").performClick()
        assertEquals(listOf<DailyEvent>(DailyEvent.HadithRetried), events)
    }
}
