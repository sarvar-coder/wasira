sealed class SurahListEvent {}

class SurahListRequested extends SurahListEvent {}

/// Records which surah the reader opened. Kept as an explicit intent because
/// future memorization features read this history to see what gets studied.
class SurahOpened extends SurahListEvent {
  SurahOpened(this.number);
  final int number;
}
