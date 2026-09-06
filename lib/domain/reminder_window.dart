/// One notification to be pending: which ayah, when, and under what id.
class Reminder {
  const Reminder({
    required this.id,
    required this.at,
    required this.ayahNumber,
  });

  final int id;
  final DateTime at;
  final int ayahNumber;
}

/// How far ahead reminders are scheduled.
///
/// macOS keeps roughly 64 pending notifications and silently drops the rest,
/// so this is a rolling window rebuilt on every launch rather than a schedule
/// running months ahead. Seven days of at most five ayahs is 35, comfortably
/// inside the cap even before today's past times are skipped.
const reminderWindowDays = 7;

/// The reminders that should be pending right now.
///
/// [times] is minutes after midnight, one per ayah of the day; [ayahsFor]
/// supplies a day's pick, including days that have not arrived — scheduling
/// has to look ahead even though history must not.
List<Reminder> reminderWindow({
  required DateTime from,
  required List<int> times,
  required List<int> Function(DateTime day) ayahsFor,
  int days = reminderWindowDays,
}) {
  final reminders = <Reminder>[];

  for (var d = 0; d < days; d++) {
    final day = DateTime(from.year, from.month, from.day + d);
    final ayahs = ayahsFor(day);

    for (var slot = 0; slot < times.length && slot < ayahs.length; slot++) {
      // Built from date parts rather than added as a Duration: on the day a
      // zone shifts, 08:00 must stay 08:00 rather than becoming 07:00.
      final at = DateTime(
        day.year,
        day.month,
        day.day,
        times[slot] ~/ 60,
        times[slot] % 60,
      );

      // A time already past today would fire the moment it is scheduled,
      // which reads as a bug rather than a reminder.
      if (!at.isAfter(from)) continue;

      reminders.add(
          Reminder(id: reminderId(day, slot), at: at, ayahNumber: ayahs[slot]));
    }
  }

  return reminders;
}

/// Stable per (day, slot), so rescheduling replaces a pending reminder instead
/// of adding a duplicate beside it.
///
/// Days since the epoch leaves room for the slots and stays inside the 32-bit
/// id the platforms expect.
int reminderId(DateTime day, int slot) =>
    (DateTime(day.year, day.month, day.day).millisecondsSinceEpoch ~/
                Duration.millisecondsPerDay) *
            8 +
        slot;
