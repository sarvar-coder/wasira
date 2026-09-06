import '../../domain/models/ayah.dart';
import '../../domain/models/surah.dart';

sealed class BookmarksState {}

class BookmarksLoading extends BookmarksState {}

class BookmarksFailed extends BookmarksState {
  BookmarksFailed(this.error);
  final Object error;
}

class BookmarksLoaded extends BookmarksState {
  BookmarksLoaded(this.entries);

  /// In Quran order. Empty is the ordinary first state, not an error.
  final List<Bookmark> entries;
}

class Bookmark {
  const Bookmark({
    required this.ayah,
    required this.surah,
    this.translation,
  });

  /// Any opening Bismillah is already split off — a bookmark can land on
  /// ayah 1.
  final Ayah ayah;
  final Surah surah;
  final String? translation;
}
