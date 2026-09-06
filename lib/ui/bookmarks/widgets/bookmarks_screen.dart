import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/bookmark_repository.dart';
import '../../../data/repositories/quran_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../domain/ayah_citation.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/tokens.dart';
import '../../reader/widgets/reader_screen.dart';
import '../bookmarks_bloc.dart';
import '../bookmarks_event.dart';
import '../bookmarks_state.dart';

/// Saved ayahs, flat and in Quran order — the only order a list of ayahs
/// reads in. Tapping one opens the reader at it.
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({
    super.key,
    required this.repository,
    required this.settings,
    required this.bookmarks,
    required this.translationEdition,
  });

  final QuranRepository repository;
  final SettingsRepository settings;
  final BookmarkRepository bookmarks;
  final String? translationEdition;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<BookmarksBloc, BookmarksState>(
        builder: (context, state) => switch (state) {
          BookmarksLoading() =>
            const Center(child: CircularProgressIndicator()),
          BookmarksFailed(:final error) => Center(
              child: Text('$error',
                  style: TextStyle(color: Tokens.of(context).muted)),
            ),
          BookmarksLoaded(:final entries) when entries.isEmpty => const _Empty(),
          BookmarksLoaded(:final entries) => ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (context, _) =>
                  Divider(height: 1, color: Tokens.of(context).divider),
              itemBuilder: (context, i) => _BookmarkTile(
                bookmark: entries[i],
                onOpen: () => _openReader(context, entries[i].ayah.surah,
                    entries[i].ayah.number),
              ),
            ),
        },
      );

  void _openReader(BuildContext context, int surah, int ayahNumber) {
    final bloc = context.read<BookmarksBloc>();
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
          builder: (_) => ReaderScreen(
            surah: surah,
            repository: repository,
            settings: settings,
            translationEdition: translationEdition,
            bookmarks: bookmarks,
            initialAyah: ayahNumber,
          ),
        ))
        // The reader can unsave the ayah that was tapped, so the list is
        // re-read on the way back rather than showing what it held before.
        .then((_) => bloc.add(BookmarksRequested()));
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final tokens = Tokens.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.noBookmarks, style: TextStyle(color: tokens.muted)),
          const SizedBox(height: 6),
          Text(l10n.bookmarksHint,
              style: TextStyle(fontSize: 12, color: tokens.muted)),
        ],
      ),
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  const _BookmarkTile({required this.bookmark, required this.onOpen});

  final Bookmark bookmark;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = Tokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final reference =
        ayahReference(bookmark.surah.number, bookmark.ayah.numberInSurah);

    return ListTile(
      onTap: onOpen,
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
      title: Text('${bookmark.surah.nameEn}  ·  $reference',
          style: TextStyle(fontSize: 12, color: tokens.muted)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Two lines of it: enough to recognise which ayah this is without
            // turning the list into a second reader.
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                bookmark.ayah.textAr,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 18),
              ),
            ),
            if (bookmark.translation case final translation?
                when translation.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(translation,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: tokens.muted)),
            ],
          ],
        ),
      ),
      trailing: PopupMenuButton<void>(
        tooltip: l10n.removeBookmark,
        icon: Icon(Icons.more_horiz, size: 18, color: tokens.muted),
        itemBuilder: (context) => [
          PopupMenuItem(
            onTap: () => context
                .read<BookmarksBloc>()
                .add(BookmarkRemoved(bookmark.ayah.number)),
            child: Text(l10n.removeBookmark),
          ),
        ],
      ),
    );
  }
}
