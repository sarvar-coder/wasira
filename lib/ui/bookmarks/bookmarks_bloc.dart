import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/bookmark_repository.dart';
import '../../data/repositories/quran_repository.dart';
import '../../domain/bismillah.dart';
import 'bookmarks_event.dart';
import 'bookmarks_state.dart';

class BookmarksBloc extends Bloc<BookmarksEvent, BookmarksState> {
  BookmarksBloc({
    required this.repository,
    required this.bookmarks,
    required this.translationEdition,
  }) : super(BookmarksLoading()) {
    on<BookmarksRequested>((event, emit) => emit(_read()));

    on<BookmarkRemoved>((event, emit) {
      bookmarks.toggle(event.ayahNumber);
      emit(_read());
    });
  }

  final QuranRepository repository;
  final BookmarkRepository bookmarks;
  final String? translationEdition;

  /// Read straight from disk rather than kept in the state and mutated: the
  /// reader saves and unsaves through the same table, so this list is right
  /// whenever it is shown instead of only when it was built.
  BookmarksState _read() {
    try {
      final numbers = bookmarks.all;
      final ayahs = repository.ayahsByNumber(numbers);
      final translations =
          repository.translationsByNumber(numbers, translationEdition);
      final surahs = {
        for (final s in repository.surahsLocal()) s.number: s,
      };

      return BookmarksLoaded([
        for (final ayah in ayahs)
          if (surahs[ayah.surah] case final surah?)
            Bookmark(
              ayah: withoutOpeningBismillah(ayah),
              surah: surah,
              translation: translations[ayah.number],
            ),
      ]);
    } catch (error) {
      return BookmarksFailed(error);
    }
  }
}
