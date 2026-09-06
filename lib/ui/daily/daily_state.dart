import '../../domain/models/ayah.dart';
import '../../domain/models/surah.dart';

sealed class DailyState {}

class DailyLoading extends DailyState {}

class DailyFailed extends DailyState {
  DailyFailed(this.error);
  final Object error;
}

/// The pick is made and stored, but the Quran text has not finished syncing,
/// so there is nothing to render yet. Distinct from an error: waiting is the
/// correct outcome here, and the day is already fixed.
class DailyWaitingForSync extends DailyState {
  DailyWaitingForSync(this.date);
  final DateTime date;
}

class DailyLoaded extends DailyState {
  DailyLoaded({
    required this.date,
    required this.ayahs,
    required this.arabicSize,
    required this.count,
    required this.reminderTimes,
    required this.since,
    this.expanded = const <int>{},
  });

  final DateTime date;
  final List<DailyAyah> ayahs;
  final double arabicSize;

  /// How many ayahs a day offers, and one reminder time per ayah.
  final int count;
  final List<int> reminderTimes;

  /// The first day the calendar offers: when the app started keeping days.
  final DateTime since;

  final Set<int> expanded;

  DailyLoaded copyWith({Set<int>? expanded}) => DailyLoaded(
        date: date,
        ayahs: ayahs,
        arabicSize: arabicSize,
        count: count,
        reminderTimes: reminderTimes,
        since: since,
        expanded: expanded ?? this.expanded,
      );
}

/// One ayah of a day, with the surah it belongs to — the daily pick is
/// scattered, so a bare ayah number tells the reader nothing.
class DailyAyah {
  const DailyAyah({required this.ayah, required this.surah, this.translation});

  /// Any opening Bismillah is already split off, exactly as in the reader.
  final Ayah ayah;
  final Surah surah;
  final String? translation;
}
