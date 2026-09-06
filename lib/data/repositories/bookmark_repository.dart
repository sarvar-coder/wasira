import '../services/database_service.dart';

/// Saved ayahs.
///
/// Bookmarks are a set of global ayah numbers and nothing more. The `note`
/// column exists in the schema and stays unused in v1 — a notes feature is a
/// different product decision, not a field to fill in because it is there.
class BookmarkRepository {
  const BookmarkRepository(this.db);

  final DatabaseService db;

  /// In Quran order, which is the only order a list of ayahs reads in.
  List<int> get all => db.readBookmarks();

  bool contains(int ayahNumber) => db.isBookmarked(ayahNumber);

  /// Returns whether the ayah is bookmarked afterwards, so the caller does not
  /// have to ask again.
  bool toggle(int ayahNumber) {
    if (contains(ayahNumber)) {
      db.removeBookmark(ayahNumber);
      return false;
    }
    db.addBookmark(ayahNumber);
    return true;
  }
}
