import 'dart:math';

/// A calendar day as a stable key: `2026-09-06`.
///
/// Local components only. Converting to UTC first would move the boundary for
/// anyone not on it and hand them yesterday's ayahs at breakfast.
String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// [count] distinct global ayah numbers, 1 to [total], for one day.
///
/// Deterministic in (seed, date): the same pair yields the same ayahs however
/// often it is asked, which is what lets a day the user missed be regenerated
/// rather than kept forever.
///
/// Determinism holds *within* an SDK — Dart does not promise the same stream
/// from `Random(seed)` across releases. That is why the result is stored the
/// first time it is used; see [DailyRepository].
List<int> dailyAyahs({
  required int seed,
  required DateTime date,
  required int count,
  int total = 6236,
}) {
  final wanted = count.clamp(1, total);
  final random = Random(seed ^ dateHash(date));
  final picked = <int>{};
  while (picked.length < wanted) {
    picked.add(random.nextInt(total) + 1);
  }
  // Ascending, so a day reads in the order of the Quran rather than the order
  // the generator happened to draw.
  return picked.toList()..sort();
}

/// Distinct per calendar day and monotonic, so consecutive days seed the
/// generator differently.
int dateHash(DateTime date) => date.year * 10000 + date.month * 100 + date.day;
