import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/settings_repository.dart';
import '../../data/services/audio_player_service.dart';
import 'audio_event.dart';
import 'audio_state.dart';

class AudioBloc extends Bloc<AudioEvent, AudioState> {
  AudioBloc({
    required this.player,
    required this.settings,
    required this.surah,
    required this.ayahNumbers,
  }) : super(AudioState(reciter: settings.reciter)) {
    on<PlaybackRequested>(_onPlay);
    on<PlaybackPaused>(_onPause);
    on<NextAyahRequested>((e, emit) => player.nextAyah());
    on<PreviousAyahRequested>((e, emit) => player.previousAyah());
    on<RecitationRepeatChanged>(_onRepeat);
    on<ReciterChanged>(_onReciter);
    on<AyahSounded>((e, emit) =>
        emit(state.copyWith(currentAyah: e.ayahNumber, clearAyah: e.ayahNumber == null)));
    on<PlaybackFailed>((e, emit) =>
        emit(state.copyWith(error: e.error, playing: false)));

    _ayahSub = player.currentAyah.listen(
      (n) => add(AyahSounded(n)),
      onError: (Object e) => add(PlaybackFailed(e)),
    );
  }

  final AudioPlayerService player;
  final SettingsRepository settings;
  final int surah;

  /// Global ayah numbers of this surah, in order.
  final List<int> ayahNumbers;

  StreamSubscription<int?>? _ayahSub;
  bool _loaded = false;

  Future<void> _onPlay(PlaybackRequested event, Emitter<AudioState> emit) async {
    emit(state.copyWith(clearError: true));
    try {
      final startAt = event.fromAyah == null
          ? 0
          : ayahNumbers.indexOf(event.fromAyah!).clamp(0, ayahNumbers.length - 1);

      // Reload when starting somewhere new, or on the first play of this surah.
      if (!_loaded || event.fromAyah != null) {
        await player.load(
          reciter: state.reciter,
          surah: surah,
          ayahNumbers: ayahNumbers,
          startAt: startAt,
        );
        await player.setRepeat(state.repeat);
        _loaded = true;
      }
      await player.play();
      emit(state.copyWith(playing: true));
    } catch (error) {
      emit(state.copyWith(error: error, playing: false));
    }
  }

  Future<void> _onPause(PlaybackPaused event, Emitter<AudioState> emit) async {
    await player.pause();
    emit(state.copyWith(playing: false));
  }

  Future<void> _onRepeat(
      RecitationRepeatChanged event, Emitter<AudioState> emit) async {
    await player.setRepeat(event.mode);
    emit(state.copyWith(repeat: event.mode));
  }

  /// Switching reciter can switch playback path — al-Luhaidan publishes whole
  /// surahs — so the queue is rebuilt from scratch rather than swapped.
  Future<void> _onReciter(ReciterChanged event, Emitter<AudioState> emit) async {
    settings.setReciter(event.reciter);
    _loaded = false;
    final wasPlaying = state.playing;

    await player.pause();
    emit(state.copyWith(
        reciter: event.reciter, playing: false, clearAyah: true));

    if (wasPlaying) add(PlaybackRequested());
  }

  @override
  Future<void> close() async {
    await _ayahSub?.cancel();
    await player.dispose();
    return super.close();
  }
}
