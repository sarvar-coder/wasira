sealed class DailyEvent {}

/// Show today's ayah: from the cache if it is today's, otherwise fetched.
class DailyRequested extends DailyEvent {}

/// Try again after a failed fetch. Distinct from [DailyRequested] only in what
/// it records — the user asked, rather than the app starting.
class DailyRetried extends DailyEvent {}

class ArabicSizeChanged extends DailyEvent {
  ArabicSizeChanged(this.size);
  final double size;
}

/// One reminder moved. Minutes after midnight, matching how they are stored.
class ReminderTimeChanged extends DailyEvent {
  ReminderTimeChanged(this.index, this.minutes);
  final int index;
  final int minutes;
}

class TranslationExpanded extends DailyEvent {}
