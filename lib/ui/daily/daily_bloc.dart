import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/daily_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/notification_service.dart';
import '../../domain/models/edition.dart';
import 'daily_event.dart';
import 'daily_state.dart';

/// The ayah of the day, and the two things about it the user can change: how
/// large the Arabic is, and when the five reminders fire.
class DailyBloc extends Bloc<DailyEvent, DailyState> {
  DailyBloc({
    required this.daily,
    required this.settings,
    this.notifications,
  }) : super(DailyLoading()) {
    on<DailyRequested>((event, emit) => _load(emit));
    on<DailyRetried>((event, emit) => _load(emit));

    on<ArabicSizeChanged>((event, emit) {
      settings.setArabicFontSize(event.size);
      if (state case final DailyLoaded loaded) {
        emit(loaded.copyWith(arabicSize: settings.arabicFontSize));
      }
    });

    on<ReminderTimeChanged>((event, emit) async {
      final times = [...settings.reminderTimes];
      if (event.index < 0 || event.index >= times.length) return;
      times[event.index] = event.minutes;
      settings.setReminderTimes(times);
      await _reschedule();

      if (state case final DailyLoaded loaded) {
        emit(loaded.copyWith(reminderTimes: settings.reminderTimes));
      }
    });

    on<TranslationEditionChanged>((event, emit) async {
      settings.setTranslationEdition(event.edition, event.name);
      await _load(emit);
    });

    on<TranslationExpanded>((event, emit) {
      if (state case final DailyLoaded loaded) {
        emit(loaded.copyWith(expanded: true));
      }
    });
  }

  final DailyRepository daily;
  final SettingsRepository settings;

  /// Null in tests and wherever notifications are not wired up; a reminder
  /// that cannot be scheduled must not stop the ayah being shown.
  final NotificationService? notifications;

  /// Every translation the API offers, for the settings sheet. Fetched on
  /// demand rather than held in state — it is one screen, opened rarely.
  Future<List<Edition>> translations() => daily.api.translationEditions();

  Future<void> _load(Emitter<DailyState> emit) async {
    emit(DailyLoading());
    try {
      emit(DailyLoaded(
        daily: await daily
            .today(translationEdition: settings.translationEdition),
        arabicSize: settings.arabicFontSize,
        reminderTimes: settings.reminderTimes,
        translationName: settings.translationName,
      ));
    } catch (error) {
      emit(DailyUnavailable(error));
    }
  }

  /// Rewrites the five reminders whenever their times change. Failing here is
  /// not worth failing the screen for — the next launch reschedules anyway.
  Future<void> _reschedule() async {
    final service = notifications;
    if (service == null) return;
    try {
      // Idempotent after the first answer, so this is where permission is
      // asked of someone who set a time before launch ever got there.
      if (!await service.requestPermission()) return;
      await service.scheduleDaily(settings.reminderTimes);
    } catch (_) {}
  }
}
