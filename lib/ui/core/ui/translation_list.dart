import 'package:flutter/material.dart';

import '../../../domain/models/edition.dart';
import '../../../l10n/app_localizations.dart';
import '../themes/tokens.dart';

/// Every translation the API offers, grouped by language.
///
/// Shared by the first-run picker and the settings sheet: choosing a
/// translation and changing it later are the same act, and were drifting apart
/// when only onboarding could do it.
class TranslationList extends StatelessWidget {
  const TranslationList({
    super.key,
    required this.editions,
    required this.onSelected,
    this.selected,
  });

  final List<Edition> editions;
  final void Function(Edition) onSelected;

  /// The identifier currently in use, marked in the list.
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final tokens = Tokens.of(context);
    final l10n = AppLocalizations.of(context)!;

    final byLanguage = <String, List<Edition>>{};
    for (final e in editions) {
      byLanguage.putIfAbsent(e.language, () => []).add(e);
    }
    final languages = byLanguage.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: languages.length,
      itemBuilder: (context, i) {
        final language = languages[i];
        final group = byLanguage[language]!;

        return ExpansionTile(
          // Opened on the language already in use, so changing a translation
          // starts where the reader already is rather than at the top of 48
          // collapsed languages.
          initiallyExpanded:
              group.any((e) => e.identifier == selected),
          title: Text(language.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(l10n.translationsAvailable(group.length),
              style: TextStyle(color: tokens.muted, fontSize: 12)),
          children: [
            for (final e in group)
              ListTile(
                title: Text(e.englishName),
                subtitle: Text(e.name,
                    style: TextStyle(color: tokens.muted, fontSize: 12)),
                trailing: e.identifier == selected
                    ? Icon(Icons.check, size: 16, color: tokens.accent)
                    : null,
                onTap: () => onSelected(e),
              ),
          ],
        );
      },
    );
  }
}
