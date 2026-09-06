import '../../data/services/audio_player_service.dart';
import '../../domain/reciter.dart';

/// Playback state is a set of orthogonal facts rather than a sequence of
/// phases, so this is one class with fields rather than the sealed hierarchy
/// used for load-once flows like sync. A reciter, a repeat mode and a playing
/// flag all vary independently.
class AudioState {
  const AudioState({
    required this.reciter,
    this.playing = false,
    this.repeat = RecitationRepeat.none,
    this.currentAyah,
    this.error,
  });

  final Reciter reciter;
  final bool playing;
  final RecitationRepeat repeat;

  /// Global ayah number now sounding. Always null for a surah-by-surah
  /// reciter, which cannot report ayah position.
  final int? currentAyah;

  final Object? error;

  /// Whether ayah-level controls apply at all. False for al-Luhaidan, who
  /// publishes one file per surah.
  bool get ayahControlsApply => reciter.supportsAyahControls;

  AudioState copyWith({
    Reciter? reciter,
    bool? playing,
    RecitationRepeat? repeat,
    int? currentAyah,
    Object? error,
    bool clearError = false,
    bool clearAyah = false,
  }) =>
      AudioState(
        reciter: reciter ?? this.reciter,
        playing: playing ?? this.playing,
        repeat: repeat ?? this.repeat,
        currentAyah: clearAyah ? null : (currentAyah ?? this.currentAyah),
        error: clearError ? null : (error ?? this.error),
      );
}
