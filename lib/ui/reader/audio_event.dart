import '../../data/services/audio_player_service.dart';
import '../../domain/reciter.dart';

sealed class AudioEvent {}

/// Start playing the surah, from [fromAyah] if given.
class PlaybackRequested extends AudioEvent {
  PlaybackRequested({this.fromAyah});
  final int? fromAyah;
}

class PlaybackPaused extends AudioEvent {}

class NextAyahRequested extends AudioEvent {}

class PreviousAyahRequested extends AudioEvent {}

class RecitationRepeatChanged extends AudioEvent {
  RecitationRepeatChanged(this.mode);
  final RecitationRepeat mode;
}

class ReciterChanged extends AudioEvent {
  ReciterChanged(this.reciter);
  final Reciter reciter;
}

/// Emitted from the player as playback moves between ayahs.
class AyahSounded extends AudioEvent {
  AyahSounded(this.ayahNumber);
  final int? ayahNumber;
}

class PlaybackFailed extends AudioEvent {
  PlaybackFailed(this.error);
  final Object error;
}
