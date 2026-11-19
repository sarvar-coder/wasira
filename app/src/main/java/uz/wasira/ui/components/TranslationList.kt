package uz.wasira.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uz.wasira.R
import uz.wasira.domain.Edition
import uz.wasira.ui.theme.wasira

/** Every translation grouped by language code, languages sorted. */
fun groupByLanguage(editions: List<Edition>): Map<String, List<Edition>> =
    editions.groupBy { it.language }.toSortedMap()

/**
 * Every translation the API offers, grouped by language. Shared by the
 * first-run picker and the settings picker: choosing a translation and changing
 * it later are the same act. Ported from lib/ui/core/ui/translation_list.dart.
 */
@Composable
fun TranslationList(
    editions: List<Edition>,
    onSelected: (Edition) -> Unit,
    modifier: Modifier = Modifier,
    selected: String? = null,
) {
    val groups = remember(editions) { groupByLanguage(editions) }
    // Opened on the language already in use, so changing a translation starts
    // where the reader already is rather than at the top of 48 collapsed languages.
    val initial = remember(groups, selected) {
        groups.filterValues { g -> g.any { it.identifier == selected } }.keys.joinToString(",")
    }
    var open by rememberSaveable(initial) { mutableStateOf(initial) }
    val openSet = open.split(',').filter { it.isNotEmpty() }.toSet()
    val colors = MaterialTheme.wasira
    val itemColors = ListItemDefaults.colors(containerColor = Color.Transparent)

    LazyColumn(modifier, contentPadding = PaddingValues(horizontal = 8.dp)) {
        groups.forEach { (language, group) ->
            item(key = "h:$language") {
                ListItem(
                    modifier = Modifier.clickable {
                        open = (if (language in openSet) openSet - language else openSet + language)
                            .joinToString(",")
                    },
                    colors = itemColors,
                    headlineContent = {
                        Text(language.uppercase(), fontWeight = FontWeight.SemiBold)
                    },
                    supportingContent = {
                        Text(
                            stringResource(R.string.translations_available, group.size),
                            color = colors.muted,
                            fontSize = 12.sp,
                        )
                    },
                )
            }
            if (language in openSet) {
                items(group, key = { "e:${it.identifier}" }) { e ->
                    ListItem(
                        modifier = Modifier.clickable { onSelected(e) },
                        colors = itemColors,
                        headlineContent = { Text(e.englishName) },
                        supportingContent = {
                            Text(e.name, color = colors.muted, fontSize = 12.sp)
                        },
                        trailingContent = if (e.identifier == selected) {
                            {
                                Icon(
                                    painterResource(R.drawable.ic_check),
                                    contentDescription = null,
                                    tint = colors.accent,
                                    modifier = Modifier.size(16.dp),
                                )
                            }
                        } else null,
                    )
                }
            }
            item(key = "d:$language") { HorizontalDivider(color = colors.divider) }
        }
    }
}
