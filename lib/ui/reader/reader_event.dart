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
