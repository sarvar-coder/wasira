import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../domain/ayah_citation.dart';
import '../../../domain/models/ayah.dart';
import '../../../domain/models/surah.dart';
import '../../../l10n/app_localizations.dart';
import '../audio_bloc.dart';
import '../audio_event.dart';
import '../reader_bloc.dart';
import '../reader_event.dart';

enum _AyahAction { bookmark, playFromHere, copy, share }

/// Right-click or long-press on an ayah.
///
/// Opened at the pointer rather than as a sheet: on macOS a context menu is
/// what a right-click is expected to produce, and the same menu serves
/// long-press on touch.
Future<void> showAyahMenu(
  BuildContext context, {
  required Offset at,
  required Ayah ayah,
  required Surah surah,
  required String? translation,
  required bool bookmarked,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final reader = context.read<ReaderBloc>();
  final audio = context.read<AudioBloc>();
  final messenger = ScaffoldMessenger.of(context);
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;

  // Al-Luhaidan publishes whole surahs, so there is no "here" to play from.
  // Shown disabled with the reason rather than hidden, as everywhere else.
  final ayahAudio = audio.state.ayahControlsApply;

  final action = await showMenu<_AyahAction>(
    context: context,
    position: RelativeRect.fromRect(at & Size.zero, Offset.zero & overlay.size),
    items: [
      PopupMenuItem(
        value: _AyahAction.bookmark,
        child: Text(bookmarked ? l10n.removeBookmark : l10n.bookmark),
      ),
      PopupMenuItem(
        value: _AyahAction.playFromHere,
        enabled: ayahAudio,
        // The reason rides on the disabled item rather than the item
        // disappearing, same as in the audio bar.
        child: ayahAudio
            ? Text(l10n.playFromHere)
            : Tooltip(
                message: l10n.wholeSurahReciter,
                child: Text(l10n.playFromHere),
              ),
      ),
      PopupMenuItem(value: _AyahAction.copy, child: Text(l10n.copyAyah)),
      PopupMenuItem(value: _AyahAction.share, child: Text(l10n.shareAyah)),
    ],
  );
  if (action == null) return;

  final citation = ayahCitation(
    arabic: ayah.textAr,
    translation: translation,
    surahName: surah.nameEn,
    surah: surah.number,
    numberInSurah: ayah.numberInSurah,
  );

  switch (action) {
    case _AyahAction.bookmark:
      reader.add(BookmarkToggled(ayah.number));
    case _AyahAction.playFromHere:
      audio.add(PlaybackRequested(fromAyah: ayah.number));
    case _AyahAction.copy:
      await Clipboard.setData(ClipboardData(text: citation));
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.copied),
        duration: const Duration(seconds: 2),
      ));
    case _AyahAction.share:
      await SharePlus.instance.share(ShareParams(
        text: citation,
        subject: '${surah.nameEn} '
            '${ayahReference(surah.number, ayah.numberInSurah)}',
      ));
  }
}
