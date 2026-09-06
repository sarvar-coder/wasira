import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/quran_repository.dart';
import 'surah_list_event.dart';
import 'surah_list_state.dart';

class SurahListBloc extends Bloc<SurahListEvent, SurahListState> {
  SurahListBloc(this.repository) : super(SurahListLoading()) {
    on<SurahListRequested>((event, emit) async {
      emit(SurahListLoading());
      try {
        emit(SurahListLoaded(await repository.surahs()));
      } catch (error) {
        emit(SurahListFailed(error));
      }
    });

    on<SurahOpened>((event, emit) {
      if (state case SurahListLoaded(:final surahs)) {
        emit(SurahListLoaded(surahs, opened: event.number));
      }
    });
  }

  final QuranRepository repository;
}
