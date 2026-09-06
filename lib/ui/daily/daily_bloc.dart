import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/daily_repository.dart';
import '../../data/repositories/quran_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/bismillah.dart';
import '../../domain/models/ayah.dart';
import 'daily_event.dart';
import 'daily_state.dart';

/// The ayahs of one day, and the two things about them the user can change:
/// how many there are and when they are reminded.
class DailyBloc extends Bloc<DailyEvent, DailyState> {
  DailyBloc({
    required this.repository,
    required this.daily,
    required this.settings,
    required this.translationEdition,
  }) : super(DailyLoading()) {
    on<DailyRequested>((event, emit) => _load(DateTime.now(), emit));
    on<DaySelected>((event, emit) => _load(event.date, emit));

    on<DailyCountChanged>((event, emit) async {
      settings.setDailyCount(event.count);
      // Today is re-read rather than regenerated: a day already stored keeps
      // the number of ayahs it was read with.
      await _load(_date, emit);
    });

    on<ReminderTimeChanged>((event, emit) async {
      final times = [...settings.reminderTimes];
      if (event.index < 0 || event.index >= times.length) return;
      times[event.index] = event.minutes;
      settings.setReminderTimes(times);
      await _load(_date, emit);
    });

    on<TranslationExpanded>((event, emit) {
      if (state case final DailyLoaded loaded) {
        emit(loaded.copyWith(expanded: {...loaded.expanded, event.ayahNumber}));
      }
    });
  }

  final QuranRepository repository;
  final DailyRepository daily;
  final SettingsRepository settings;
  final String? translationEdition;

  /// The day on screen. Settings changes reload it rather than jumping to
  /// today, so changing the count while looking at last Tuesday stays there.
  DateTime _date = DateTime.now();

  Future<void> _load(DateTime date, Emitter<DailyState> emit) async {
    emit(DailyLoading());
    try {
      _date = date;
      final numbers = daily.ayahsFor(date);
      final surahs = await repository.surahs();
      final ayahs = repository.ayahsByNumber(numbers);

      // The sync writes 6236 rows over a few seconds; until the day's ayahs
      // are among them there is nothing to show.
      if (ayahs.length < numbers.length) {
        emit(DailyWaitingForSync(date));
        return;
      }

      final translations =
          repository.translationsByNumber(numbers, translationEdition);

      emit(DailyLoaded(
        date: date,
        arabicSize: settings.arabicFontSize,
        count: settings.dailyCount,
        reminderTimes: settings.reminderTimes,
        since: settings.dailySince,
        ayahs: [
          for (final ayah in ayahs)
            DailyAyah(
              ayah: _withoutOpeningBismillah(ayah),
              surah: surahs.firstWhere((s) => s.number == ayah.surah),
              translation: translations[ayah.number],
            ),
        ],
      ));
    } catch (error) {
      emit(DailyFailed(error));
    }
  }

  /// A daily pick can land on ayah 1, which arrives with the Bismillah glued
  /// on. Splitting it here keeps the ayah and its translation agreeing, the
  /// same as the reader does.
  static Ayah _withoutOpeningBismillah(Ayah a) {
    final split = splitOpeningBismillah(
      surah: a.surah,
      numberInSurah: a.numberInSurah,
      text: a.textAr,
    );
    if (split.text == a.textAr) return a;

    return Ayah(
      number: a.number,
      surah: a.surah,
      numberInSurah: a.numberInSurah,
      juz: a.juz,
      page: a.page,
      hizbQuarter: a.hizbQuarter,
      ruku: a.ruku,
      manzil: a.manzil,
      sajda: a.sajda,
      sajdaObligatory: a.sajdaObligatory,
      textAr: split.text,
    );
  }
}
