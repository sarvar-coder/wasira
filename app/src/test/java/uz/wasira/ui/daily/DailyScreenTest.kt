package uz.wasira.ui.daily

import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
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
    @get:Rule val compose = createComposeRule()

    private val settings = Settings("en.sahih", "Saheeh International", 30, listOf(480, 660, 840, 1020, 1200))

    private fun show(
        ayah: DailyAyah,
        expanded: Boolean = false,
        hadith: HadithState = HadithState.Idle,
        onEvent: (DailyEvent) -> Unit = {},
    ) {
        compose.setContent {
            WasiraTheme(darkTheme = false) {
                DailyScreen(DailyState.Loaded(ayah, settings, expanded), TranslationsState.Idle, onEvent, hadith = hadith)
            }
        }
    }

    @Test fun `header names the surah and cites surah colon ayah`() {
        show(fixture("golden_2_255"))
        compose.onNodeWithText("Al-Baqara  ·  2:255").assertExists()
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

    @Test fun `no show more at 300 characters`() {
        show(fixture("golden_1_1").copy(translation = "a".repeat(300)))
        compose.onAllNodesWithText("Show more").assertCountEquals(0)
    }

    @Test fun `show more at 301 characters asks to expand`() {
        val events = mutableListOf<DailyEvent>()
        show(fixture("golden_1_1").copy(translation = "a".repeat(301)), onEvent = { events += it })
        compose.onNodeWithText("Show more").performClick()
        assertEquals(listOf<DailyEvent>(DailyEvent.TranslationExpanded), events)
    }

    @Test fun `expanded shows no show more`() {
        show(fixture("golden_1_1").copy(translation = "a".repeat(301)), expanded = true)
        compose.onAllNodesWithText("Show more").assertCountEquals(0)
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

    private fun loadedHadith(hadith: Hadith = HADITH, explanationOpen: Boolean = false) =
        HadithState.Loaded(DailyHadith("2026-11-19", hadith), explanationOpen = explanationOpen)

    @Test fun `the hadith sits under the ayah with its source and grade`() {
        show(fixture("golden_1_1"), hadith = loadedHadith())
        compose.onNodeWithText("Hadith of the day").assertExists()
        compose.onNodeWithText(HADITH.arabic).assertExists()
        compose.onNodeWithText(HADITH.translation!!).assertExists()
        compose.onNodeWithText("Narrated by At-Tirmidhi  ·  Authentic").assertExists()
    }

    @Test fun `the explanation is closed until asked for`() {
        val events = mutableListOf<DailyEvent>()
        show(fixture("golden_1_1"), hadith = loadedHadith(), onEvent = { events += it })
        compose.onAllNodesWithText(HADITH.explanation).assertCountEquals(0)
        compose.onNodeWithText("Explanation").performScrollTo().performClick()
        assertEquals(listOf<DailyEvent>(DailyEvent.HadithExplanationToggled), events)
    }

    @Test fun `an open explanation shows the sharh and the lessons`() {
        show(fixture("golden_1_1"), hadith = loadedHadith(explanationOpen = true))
        compose.onNodeWithText(HADITH.explanation).assertExists()
        compose.onNodeWithText("Lessons").assertExists()
        compose.onNodeWithText("Hide explanation").assertExists()
    }

    @Test fun `a long hadith clamps with show more`() {
        val events = mutableListOf<DailyEvent>()
        val long = HADITH.copy(translation = "a".repeat(301))
        show(fixture("golden_1_1"), hadith = loadedHadith(long), onEvent = { events += it })
        compose.onNodeWithText("Show more").performScrollTo().performClick()
        assertEquals(listOf<DailyEvent>(DailyEvent.HadithExpanded), events)
    }

    @Test fun `an arabic hadith has no translation line`() {
        show(fixture("golden_1_1"), hadith = loadedHadith(HADITH.copy(language = "ar", translation = null)))
        compose.onNodeWithText(HADITH.arabic).assertExists()
        compose.onAllNodesWithTag(HADITH_TRANSLATION_TAG).assertCountEquals(0)
    }

    @Test fun `hadith unavailable - the ayah stays and the hadith offers a retry`() {
        val events = mutableListOf<DailyEvent>()
        show(fixture("golden_1_1"), hadith = HadithState.Unavailable, onEvent = { events += it })
        compose.onNodeWithText("Al-Faatiha  ·  1:1").assertExists()
        compose.onNodeWithText("Could not reach the hadith service").assertExists()
        compose.onNodeWithText("Try again").performScrollTo().performClick()
        assertEquals(listOf<DailyEvent>(DailyEvent.HadithRetried), events)
    }
}
