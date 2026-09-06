import '../../domain/models/ayah.dart';
import '../../domain/models/surah.dart';

sealed class ReaderState {}

class ReaderLoading extends ReaderState {}

class ReaderFailed extends ReaderState {
  ReaderFailed(this.error);
  final Object error;
}

class ReaderLoaded extends ReaderState {
  ReaderLoaded({
    required this.surah,
    required this.ayahs,
    required this.translations,
    required this.bismillahHeader,
    required this.arabicSize,
    this.expanded = const <int>{},
  });

  final Surah surah;

  /// Ayah 1 already has any opening Bismillah removed.
  final List<Ayah> ayahs;

  /// Keyed by global ayah number. Empty when reading Arabic only.
  final Map<int, String> translations;

  /// The Bismillah to show above the surah, or null for Al-Fatiha and
  /// At-Tawbah.
  final String? bismillahHeader;

  final double arabicSize;
  final Set<int> expanded;

  ReaderLoaded copyWith({Set<int>? expanded, double? arabicSize}) =>
      ReaderLoaded(
        surah: surah,
        ayahs: ayahs,
        translations: translations,
        bismillahHeader: bismillahHeader,
        arabicSize: arabicSize ?? this.arabicSize,
        expanded: expanded ?? this.expanded,
      );
}
