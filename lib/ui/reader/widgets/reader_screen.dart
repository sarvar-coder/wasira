import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/quran_repository.dart';
import '../../core/themes/tokens.dart';
import '../../core/ui/arabic_text.dart';
import '../reader_bloc.dart';
import '../reader_event.dart';
import '../reader_state.dart';
import 'ayah_tile.dart';

class ReaderScreen extends StatelessWidget {
  const ReaderScreen({
    super.key,
    required this.surah,
    required this.repository,
    required this.translationEdition,
    this.arabicSize = 30,
  });

  final int surah;
  final QuranRepository repository;
  final String? translationEdition;
  final double arabicSize;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ReaderBloc(
          repository: repository,
          translationEdition: translationEdition,
        )..add(SurahRequested(surah)),
        child: _ReaderView(arabicSize: arabicSize),
      );
}

class _ReaderView extends StatelessWidget {
  const _ReaderView({required this.arabicSize});
  final double arabicSize;

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
          final ReaderLoaded loaded => Scaffold(
              appBar: AppBar(
                title: Text(loaded.surah.nameEn),
                titleTextStyle: Theme.of(context).textTheme.titleMedium,
              ),
              body: _Ayahs(loaded: loaded, arabicSize: arabicSize),
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
        return AyahTile(
          ayah: ayah,
          arabicSize: arabicSize,
          translation: loaded.translations[ayah.number],
          expanded: loaded.expanded.contains(ayah.number),
          onExpand: () => context
              .read<ReaderBloc>()
              .add(TranslationExpanded(ayah.number)),
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
