sealed class BookmarksEvent {}

class BookmarksRequested extends BookmarksEvent {}

class BookmarkRemoved extends BookmarksEvent {
  BookmarkRemoved(this.ayahNumber);
  final int ayahNumber;
}
