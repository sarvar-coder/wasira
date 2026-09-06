import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/surah.dart';
import '../../../data/repositories/quran_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/tokens.dart';
import '../../reader/widgets/reader_screen.dart';
import '../surah_list_bloc.dart';
import '../surah_list_event.dart';
import '../surah_list_state.dart';

/// The 114 surahs. Stays scrollable while the background sync runs — that is
/// the whole point of painting this from a 19 KB request.
class SurahListScreen extends StatelessWidget {
  const SurahListScreen({
    super.key,
    required this.repository,
    required this.settings,
    required this.translationEdition,
  });

  final QuranRepository repository;
  final SettingsRepository settings;
  final String? translationEdition;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SurahListBloc, SurahListState>(
        builder: (context, state) => switch (state) {
          SurahListLoading() => const Center(child: CircularProgressIndicator()),
          SurahListFailed(:final error) => Center(
              child: Text(
                  '${AppLocalizations.of(context)!.surahsUnavailable}: $error',
                  style: TextStyle(color: Tokens.of(context).muted)),
            ),
          SurahListLoaded(:final surahs) => ListView.builder(
              itemCount: surahs.length,
              itemBuilder: (context, i) => _SurahTile(
                  surah: surahs[i],
                  repository: repository,
                  settings: settings,
                  translationEdition: translationEdition),
            ),
        },
      );
}

class _SurahTile extends StatelessWidget {
  const _SurahTile({
    required this.surah,
    required this.repository,
    required this.settings,
    required this.translationEdition,
  });
  final Surah surah;
  final QuranRepository repository;
  final SettingsRepository settings;
  final String? translationEdition;

  @override
  Widget build(BuildContext context) {
    final tokens = Tokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    // revelationType arrives from the API as "Meccan"/"Medinan"; map it so the
    // subtitle is not half-translated.
    final revelation = surah.revelationType == 'Meccan'
        ? l10n.revelationMeccan
        : l10n.revelationMedinan;
    // nameEnTranslation is an English gloss the API offers in English only.
    // Mixing it into an Arabic or Russian line reads as half-translated, and in
    // RTL the bidirectional run renders awkwardly, so show it only in English.
    final englishGloss = Localizations.localeOf(context).languageCode == 'en'
        ? '${surah.nameEnTranslation}  ·  '
        : '';

    return ListTile(
      leading: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('${surah.number}',
            style: TextStyle(
                color: tokens.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
      title: Text(surah.nameEn),
      subtitle: Text(
        '$englishGloss${l10n.ayahCount(surah.ayahCount)}  ·  $revelation',
        style: TextStyle(color: tokens.muted, fontSize: 12),
      ),
      trailing: Directionality(
        textDirection: TextDirection.rtl,
        child: Text(surah.nameAr, style: const TextStyle(fontSize: 17)),
      ),
      onTap: () {
        context.read<SurahListBloc>().add(SurahOpened(surah.number));
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ReaderScreen(
            surah: surah.number,
            repository: repository,
            settings: settings,
            translationEdition: translationEdition,
          ),
        ));
      },
    );
  }
}
