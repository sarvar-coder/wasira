import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/quran_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/tokens.dart';
import '../../core/ui/arabic_text.dart';
import '../../../data/services/audio_player_service.dart';
import '../audio_bloc.dart';
import '../audio_state.dart';
import '../reader_bloc.dart';
import '../reader_event.dart';
import '../reader_state.dart';
import 'audio_bar.dart';
import 'ayah_tile.dart';

class ReaderScreen extends StatelessWidget {
  const ReaderScreen({
    super.key,
    required this.surah,
    required this.repository,
    required this.settings,
    required this.translationEdition,
  });

  final int surah;
  final QuranRepository repository;
  final SettingsRepository settings;
  final String? translationEdition;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ReaderBloc(
          repository: repository,
          settings: settings,
          translationEdition: translationEdition,
        )..add(SurahRequested(surah)),
        child: const _ReaderView(),
      );
}

class _ReaderView extends StatelessWidget {
  const _ReaderView();

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ReaderBloc, ReaderState>(
        builder: (context, state) => switch (state) {
          ReaderLoading() => const Scaffold(
              body: Center(child: CircularProgressIndicator())),
          ReaderFailed(:final error) => Scaffold(
              appBar: AppBar(),
              body: Center(
                child: Text('$error',
                    style: TextStyle(color: Tokens.of(context).muted)),
              ),
            ),
          final ReaderLoaded loaded => BlocProvider(
              // Scoped to the open surah: its ayah numbers are the playlist.
              create: (context) => AudioBloc(
                player: AudioPlayerService(),
                settings: context.read<ReaderBloc>().settings,
                surah: loaded.surah.number,
                ayahNumbers: [for (final a in loaded.ayahs) a.number],
              ),
              child: Scaffold(
                appBar: AppBar(
                  title: Text(loaded.surah.nameEn),
                  titleTextStyle: Theme.of(context).textTheme.titleMedium,
                  actions: [_ArabicSizeButton(current: loaded.arabicSize)],
                ),
                body: _Ayahs(loaded: loaded, arabicSize: loaded.arabicSize),
                bottomNavigationBar: const AudioBar(),
              ),
            ),
        },
      );
}

class _Ayahs extends StatelessWidget {
  const _Ayahs({required this.loaded, required this.arabicSize});
  final ReaderLoaded loaded;
  final double arabicSize;

  @override
  Widget build(BuildContext context) {
    final header = loaded.bismillahHeader;
    // The header occupies index 0 when present, so ayahs shift by one.
    final offset = header == null ? 0 : 1;

    return ListView.builder(
      itemCount: loaded.ayahs.length + offset,
      itemBuilder: (context, i) {
        if (header != null && i == 0) {
          return _BismillahHeader(text: header, size: arabicSize);
        }
        final ayah = loaded.ayahs[i - offset];
        return BlocSelector<AudioBloc, AudioState, bool>(
          selector: (audio) => audio.currentAyah == ayah.number,
          builder: (context, sounding) => AyahTile(
            ayah: ayah,
            arabicSize: arabicSize,
            translation: loaded.translations[ayah.number],
            expanded: loaded.expanded.contains(ayah.number),
            highlighted: sounding,
            onExpand: () => context
                .read<ReaderBloc>()
                .add(TranslationExpanded(ayah.number)),
          ),
        );
      },
    );
  }
}

/// Shown above every surah except Al-Fatiha, where the Bismillah is ayah 1, and
/// At-Tawbah, which has none.
class _BismillahHeader extends StatelessWidget {
  const _BismillahHeader({required this.text, required this.size});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: ArabicText(text, size: size * 0.9, align: TextAlign.center),
      );
}

/// Uthmani script at one fixed size is unreadable for many people, so this is
/// the one reading preference in v1. The choice persists across launches.
class _ArabicSizeButton extends StatelessWidget {
  const _ArabicSizeButton({required this.current});
  final double current;

  @override
  Widget build(BuildContext context) {
    final tokens = Tokens.of(context);

    return PopupMenuButton<double>(
      tooltip: AppLocalizations.of(context)!.arabicTextSize,
      icon: const Icon(Icons.format_size, size: 20),
      onSelected: (size) =>
          context.read<ReaderBloc>().add(ArabicSizeChanged(size)),
      itemBuilder: (context) => [
        for (final size in SettingsRepository.arabicSizes)
          PopupMenuItem(
            value: size,
            child: Row(
              children: [
                Expanded(
                  child: Text('${size.round()}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: size == current
                              ? FontWeight.w700
                              : FontWeight.w400)),
                ),
                if (size == current)
                  Icon(Icons.check, size: 16, color: tokens.accent),
              ],
            ),
          ),
      ],
    );
  }
}
