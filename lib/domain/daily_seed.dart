
/// A calendar day as a stable key: `2026-09-06`.
///
/// Local components only. Converting to UTC first would move the boundary for
/// anyone not on it and hand them yesterday's ayahs at breakfast.
String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
