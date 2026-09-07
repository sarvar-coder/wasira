import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/settings_repository.dart';
import '../../data/services/alquran_api_service.dart';
import 'onboarding_event.dart';
import 'onboarding_state.dart';

/// Choosing a translation, which is the only thing the app asks before it can
/// show an ayah.
///
/// Nothing downloads here. The app used to sync 5.3 MB and 6236 rows before it
/// could render anything; now the day's ayah is two kilobytes fetched when the
/// day needs it, so the picker's only job is to record a choice.
class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc({required this.api, required this.settings})
      : super(OnboardingLoading()) {
    on<EditionsRequested>(_onEditionsRequested);

    on<LanguageSelected>((event, emit) {
      settings.setTranslationEdition(event.edition, event.name);
      emit(OnboardingReady(event.edition));
    });
  }

  final AlquranApiService api;
  final SettingsRepository settings;

  Future<void> _onEditionsRequested(
      EditionsRequested event, Emitter<OnboardingState> emit) async {
    emit(OnboardingLoading());
    try {
      final chosen = settings.translationEdition;
      if (chosen != null) {
        emit(OnboardingReady(chosen));
        return;
      }
      emit(OnboardingChoosing(await api.translationEditions()));
    } catch (error) {
      emit(OnboardingFailed(error));
    }
  }
}
