sealed class ReaderEvent {}

class SurahRequested extends ReaderEvent {
  SurahRequested(this.surah);
  final int surah;
}

/// Records that an ayah's translation was expanded. Kept as an explicit intent
/// because it says which ayahs people actually stop and read.
class TranslationExpanded extends ReaderEvent {
  TranslationExpanded(this.ayahNumber);
  final int ayahNumber;
}

class ArabicSizeChanged extends ReaderEvent {
  ArabicSizeChanged(this.size);
  final double size;
}

/// Saving or unsaving an ayah. Recorded as intent rather than a bare setter:
/// what a reader saves is what future memorization features read.
class BookmarkToggled extends ReaderEvent {
  BookmarkToggled(this.ayahNumber);
  final int ayahNumber;
}
