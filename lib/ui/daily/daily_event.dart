sealed class DailyEvent {}

class DailyRequested extends DailyEvent {}

/// A day from the calendar. Past and today only — [DailyRepository] refuses
/// anything later.
class DaySelected extends DailyEvent {
  DaySelected(this.date);
  final DateTime date;
}

class DailyCountChanged extends DailyEvent {
  DailyCountChanged(this.count);
  final int count;
}

/// One reminder moved. Minutes after midnight, matching how they are stored.
class ReminderTimeChanged extends DailyEvent {
  ReminderTimeChanged(this.index, this.minutes);
  final int index;
  final int minutes;
}

class TranslationExpanded extends DailyEvent {
  TranslationExpanded(this.ayahNumber);
  final int ayahNumber;
}
