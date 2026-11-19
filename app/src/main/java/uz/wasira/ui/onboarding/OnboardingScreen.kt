package uz.wasira.ui.onboarding

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uz.wasira.R
import uz.wasira.domain.Edition
import uz.wasira.ui.components.TranslationList
import uz.wasira.ui.components.groupByLanguage
import uz.wasira.ui.theme.wasira

/** The translation picker. Ported from lib/ui/onboarding/widgets/onboarding_screen.dart. */
@Composable
fun OnboardingScreen(
    state: OnboardingState,
    onEvent: (OnboardingEvent) -> Unit,
    modifier: Modifier = Modifier,
) {
    Scaffold(modifier, containerColor = MaterialTheme.wasira.bg) { insets ->
        Box(Modifier.fillMaxSize().padding(insets)) {
            when (state) {
                OnboardingState.Loading -> CircularProgressIndicator(Modifier.align(Alignment.Center))
                is OnboardingState.Failed -> Failed(
                    message = state.message,
                    onRetry = { onEvent(OnboardingEvent.Retried) },
                    modifier = Modifier.align(Alignment.Center),
                )
                is OnboardingState.Choosing -> Picker(state.editions) {
                    onEvent(OnboardingEvent.TranslationChosen(it.identifier, it.englishName))
                }
                // Choosing replaces this screen with the ayah at once.
                OnboardingState.Ready -> Unit
            }
        }
    }
}

@Composable
private fun Failed(message: String, onRetry: () -> Unit, modifier: Modifier = Modifier) {
    Column(modifier.padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            stringResource(R.string.service_unreachable),
            style = MaterialTheme.typography.titleMedium,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(8.dp))
        Text(message, color = MaterialTheme.wasira.muted, fontSize = 12.sp, textAlign = TextAlign.Center)
        Spacer(Modifier.height(16.dp))
        Button(onClick = onRetry) { Text(stringResource(R.string.try_again)) }
    }
}

@Composable
private fun Picker(editions: List<Edition>, onSelected: (Edition) -> Unit) {
    val languages = remember(editions) { groupByLanguage(editions).size }
    Column(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxWidth().padding(start = 32.dp, top = 40.dp, end = 32.dp, bottom = 24.dp)) {
            Text(
                stringResource(R.string.choose_translation),
                style = MaterialTheme.typography.headlineSmall,
            )
            Spacer(Modifier.height(6.dp))
            Text(
                stringResource(R.string.picker_subtitle, editions.size, languages),
                color = MaterialTheme.wasira.muted,
            )
        }
        TranslationList(editions = editions, onSelected = onSelected, modifier = Modifier.weight(1f))
    }
}
