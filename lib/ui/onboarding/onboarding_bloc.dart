import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/repositories/quran_repository.dart';
import '../../data/services/database_service.dart';
import '../../data/services/sync_service.dart';
import 'onboarding_event.dart';
import 'onboarding_state.dart';

/// Key under which the chosen translation edition is remembered.
const kTranslationSetting = 'translation_edition';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc({
    required this.repository,
    required this.db,
    this.sync = const SyncService(),
  }) : super(OnboardingLoading()) {
    on<EditionsRequested>(_onEditionsRequested);
    on<LanguageSelected>(_onLanguageSelected);
    on<SyncProgressed>((e, emit) {
      if (state case OnboardingSyncing(:final edition)) {
        emit(OnboardingSyncing(edition, e.fraction));
      }
    });
    on<SyncFinished>((e, emit) {
      if (state case OnboardingSyncing(:final edition)) {
        db.writeSetting(kTranslationSetting, edition);
        emit(OnboardingReady(edition));
      }
    });
    on<SyncFailed>((e, emit) => emit(OnboardingFailed(e.error)));
  }

  final QuranRepository repository;
  final DatabaseService db;
  final SyncService sync;

  StreamSubscription<void>? _syncSub;

  Future<void> _onEditionsRequested(
      EditionsRequested event, Emitter<OnboardingState> emit) async {
    emit(OnboardingLoading());
    try {
      final chosen = db.readSetting(kTranslationSetting);
      if (chosen != null && repository.isSynced) {
        emit(OnboardingReady(chosen));
        return;
      }
      emit(OnboardingChoosing(await repository.translationEditions()));
    } catch (error) {
      emit(OnboardingFailed(error));
    }
  }

  Future<void> _onLanguageSelected(
      LanguageSelected event, Emitter<OnboardingState> emit) async {
    emit(OnboardingSyncing(event.edition, 0));

    // Arabic first — it is what the reader needs — then the translation.
    // Both run off the UI isolate so the surah list stays scrollable.
    final path = '${(await getApplicationSupportDirectory()).path}/wasira.db';
    try {
      await _run(path, QuranRepository.arabicEdition, isArabic: true, from: 0);
      await _run(path, event.edition, isArabic: false, from: 0.5);
      add(SyncFinished());
    } catch (error) {
      add(SyncFailed(error));
    }
  }

  /// Maps one edition's 0..1 progress onto its half of the overall bar.
  Future<void> _run(String path, String edition,
      {required bool isArabic, required double from}) async {
    await for (final p in sync.syncEdition(
        dbPath: path, editionId: edition, isArabic: isArabic)) {
      add(SyncProgressed(from + p * 0.5));
    }
  }

  @override
  Future<void> close() {
    _syncSub?.cancel();
    return super.close();
  }
}
