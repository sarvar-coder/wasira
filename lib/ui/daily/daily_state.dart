import '../../data/repositories/daily_repository.dart';

sealed class DailyState {}

class DailyLoading extends DailyState {}

/// The ayah could not be fetched and none is cached for today.
///
/// Distinct from a generic failure because the remedy is specific and the user
/// can act on it: the app needs the network once a day, and this is that once.
class DailyUnavailable extends DailyState {
  DailyUnavailable(this.error);
  final Object error;
}

class DailyLoaded extends DailyState {
  DailyLoaded({
    required this.daily,
    required this.arabicSize,
    required this.reminderTimes,
    this.expanded = false,
  });

  final DailyAyah daily;
  final double arabicSize;

  /// Five, minutes after midnight. One ayah, nudged five times.
  final List<int> reminderTimes;

  /// Whether a long translation is shown in full. uz.sodik runs to 2660
  /// characters, which buries the ayah it belongs to.
  final bool expanded;

  DailyLoaded copyWith({
    double? arabicSize,
    List<int>? reminderTimes,
    bool? expanded,
  }) =>
      DailyLoaded(
        daily: daily,
        arabicSize: arabicSize ?? this.arabicSize,
        reminderTimes: reminderTimes ?? this.reminderTimes,
        expanded: expanded ?? this.expanded,
      );
}
