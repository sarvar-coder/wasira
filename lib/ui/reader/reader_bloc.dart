import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/bookmark_repository.dart';
import '../../data/repositories/quran_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/bismillah.dart';
import 'reader_event.dart';
import 'reader_state.dart';

class ReaderBloc extends Bloc<ReaderEvent, ReaderState> {
  ReaderBloc({
    required this.repository,
    required this.settings,
    required this.translationEdition,
    required this.bookmarks,
  }) : super(ReaderLoading()) {
    on<SurahRequested>(_onSurahRequested);
    on<TranslationExpanded>((event, emit) {
      if (state case final ReaderLoaded loaded) {
        emit(loaded.copyWith(expanded: {...loaded.expanded, event.ayahNumber}));
      }
    });
    on<BookmarkToggled>((event, emit) {
      final saved = bookmarks.toggle(event.ayahNumber);
      if (state case final ReaderLoaded loaded) {
        emit(loaded.copyWith(bookmarked: {
          for (final n in loaded.bookmarked)
            if (n != event.ayahNumber) n,
          if (saved) event.ayahNumber,
        }));
      }
    });

    on<ArabicSizeChanged>((event, emit) {
      settings.setArabicFontSize(event.size);
      if (state case final ReaderLoaded loaded) {
        emit(loaded.copyWith(arabicSize: event.size));
      }
    });
  }

  final QuranRepository repository;
  final SettingsRepository settings;

  final String? translationEdition;
  final BookmarkRepository bookmarks;

  Future<void> _onSurahRequested(
      SurahRequested event, Emitter<ReaderState> emit) async {
    emit(ReaderLoading());
    try {
      final surahs = await repository.surahs();
      final surah = surahs.firstWhere((s) => s.number == event.surah);
      final ayahs = await repository.ayahs(event.surah);
      final translations =
          await repository.translations(event.surah, translationEdition);

      // Ayah 1 arrives with the Bismillah glued on; pull it apart before it
      // reaches the tile so the ayah text and its translation agree.
      final first = ayahs.first;
      final split = splitOpeningBismillah(
        surah: surah.number,
        numberInSurah: first.numberInSurah,
        text: first.textAr,
      );

      emit(ReaderLoaded(
        surah: surah,
        ayahs: [replacingText(first, split.text), ...ayahs.skip(1)],
        translations: translations,
        bismillahHeader: split.header,
        arabicSize: settings.arabicFontSize,
        bookmarked: {
          for (final a in ayahs)
            if (bookmarks.contains(a.number)) a.number,
        },
      ));
    } catch (error) {
      emit(ReaderFailed(error));
    }
  }
}
