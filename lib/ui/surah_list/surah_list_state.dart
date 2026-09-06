import '../../domain/models/surah.dart';

sealed class SurahListState {}

class SurahListLoading extends SurahListState {}

class SurahListFailed extends SurahListState {
  SurahListFailed(this.error);
  final Object error;
}

class SurahListLoaded extends SurahListState {
  SurahListLoaded(this.surahs, {this.opened});
  final List<Surah> surahs;
  final int? opened;
}
