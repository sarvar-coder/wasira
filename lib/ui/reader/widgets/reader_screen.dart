import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/bookmark_repository.dart';
import '../../../data/repositories/quran_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/tokens.dart';
import '../../core/ui/arabic_text.dart';
import '../../../data/services/audio_download_service.dart';
import '../../../data/services/audio_player_service.dart';
import '../audio_bloc.dart';
import '../audio_state.dart';
import '../reader_bloc.dart';
import '../reader_event.dart';
import '../reader_state.dart';
import 'audio_bar.dart';
import 'ayah_menu.dart';
import 'ayah_tile.dart';

class ReaderScreen extends StatelessWidget {
  const ReaderScreen({
    super.key,
    required this.surah,
    required this.repository,
    required this.settings,
    required this.translationEdition,
    required this.bookmarks,
    this.initialAyah,
  });

  final int surah;
  final QuranRepository repository;
  final SettingsRepository settings;
  final String? translationEdition;
  final BookmarkRepository bookmarks;

  /// Global ayah number to open at, when the reader was entered from a
  /// bookmark rather than from the surah list.
  final int? initialAyah;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ReaderBloc(
          repository: repository,
          settings: settings,
          translationEdition: translationEdition,
          bookmarks: bookmarks,
        )..add(SurahRequested(surah)),
        child: _ReaderView(initialAyah: initialAyah),
      );
}

class _ReaderView extends StatelessWidget {
  const _ReaderView({this.initialAyah});
  final int? initialAyah;

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
                player: AudioPlayerService(
                    downloads: context.read<AudioDownloadService>()),
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
                body: _Ayahs(
                    loaded: loaded,
                    arabicSize: loaded.arabicSize,
                    scrollTo: initialAyah),
                bottomNavigationBar: const AudioBar(),
              ),
            ),
        },
      );
}

class _Ayahs extends StatefulWidget {
  const _Ayahs({
    required this.loaded,
    required this.arabicSize,
    this.scrollTo,
  });

  final ReaderLoaded loaded;
  final double arabicSize;

  /// Global ayah number to bring into view once, on arrival from a bookmark.
  final int? scrollTo;

  @override
  State<_Ayahs> createState() => _AyahsState();
}

class _AyahsState extends State<_Ayahs> {
  final _controller = ScrollController();
  final _target = GlobalKey();
  int _attempts = 0;

  /// Two passes, because ayah tiles have no fixed height — a translation runs
  /// from 137 characters to 2660, so there is no extent to compute an offset
  /// from. A proportional jump brings the target into the build window, then
  /// ensureVisible places it exactly.
  //
  // ponytail: fine for 286 ayahs. If a long surah ever lands short, that is
  // what scrollable_positioned_list exists for.
  void _bringIntoView() {
    // An empty surah has nothing to scroll to, and the ratio below would
    // divide by zero. Not reachable today — ReaderBloc fails on `ayahs.first`
    // before this builds — so it is a guard against that changing, not a fix
    // for a bug anyone can hit.
    if (!mounted || widget.loaded.ayahs.isEmpty || _attempts++ > 5) return;

    final context = _target.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(context,
          alignment: 0.15, duration: const Duration(milliseconds: 220));
      return;
    }
    if (!_controller.hasClients) return;

    final index = widget.loaded.ayahs
        .indexWhere((a) => a.number == widget.scrollTo)
        .clamp(0, widget.loaded.ayahs.length - 1);
    _controller.jumpTo(_controller.position.maxScrollExtent *
        (index / widget.loaded.ayahs.length));
    WidgetsBinding.instance.addPostFrameCallback((_) => _bringIntoView());
  }

  @override
  void initState() {
    super.initState();
    if (widget.scrollTo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bringIntoView());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loaded = widget.loaded;
    final arabicSize = widget.arabicSize;
    final header = loaded.bismillahHeader;
    // The header occupies index 0 when present, so ayahs shift by one.
    final offset = header == null ? 0 : 1;

    return ListView.builder(
      controller: _controller,
      itemCount: loaded.ayahs.length + offset,
      itemBuilder: (context, i) {
        if (header != null && i == 0) {
          return _BismillahHeader(text: header, size: arabicSize);
        }
        final ayah = loaded.ayahs[i - offset];
        void openMenu(Offset at) => showAyahMenu(
              context,
              at: at,
              ayah: ayah,
              surah: loaded.surah,
              translation: loaded.translations[ayah.number],
              bookmarked: loaded.bookmarked.contains(ayah.number),
            );

        return BlocSelector<AudioBloc, AudioState, bool>(
          selector: (audio) => audio.currentAyah == ayah.number,
          builder: (context, sounding) => GestureDetector(
            key: ayah.number == widget.scrollTo ? _target : null,
            behavior: HitTestBehavior.opaque,
            // Right-click on desktop, long-press on touch: the same menu, and
            // the position is the pointer so it opens where the ayah is.
            onSecondaryTapDown: (d) => openMenu(d.globalPosition),
            onLongPressStart: (d) => openMenu(d.globalPosition),
            child: AyahTile(
              ayah: ayah,
              arabicSize: arabicSize,
              translation: loaded.translations[ayah.number],
              expanded: loaded.expanded.contains(ayah.number),
              highlighted: sounding,
              bookmarked: loaded.bookmarked.contains(ayah.number),
              onExpand: () => context
                  .read<ReaderBloc>()
                  .add(TranslationExpanded(ayah.number)),
            ),
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
