import 'models/surah.dart';

/// Global ayah numbers, 1 to 6236, for a surah.
///
/// They are contiguous and run in surah order, so a running total of the ayah
/// counts is enough — no ayah rows needed. That matters: the 114 surah headers
/// arrive in one 19 KB request, so audio can be downloaded before the text sync
/// has finished writing 6236 rows.
Map<int, List<int>> ayahNumbersBySurah(List<Surah> surahs) {
  final ordered = [...surahs]..sort((a, b) => a.number.compareTo(b.number));
  var next = 1;
  return {
    for (final surah in ordered)
      surah.number: [for (var i = 0; i < surah.ayahCount; i++) next++],
  };
}
