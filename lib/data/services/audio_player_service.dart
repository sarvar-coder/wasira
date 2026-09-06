import 'package:just_audio/just_audio.dart';

import '../../domain/audio_url.dart';
import '../../domain/reciter.dart';

/// What the player is repeating.
enum RepeatMode {
  /// Play through and stop at the end of the surah.
  none,

  /// Repeat the current ayah. The core hifz loop.
  ayah,

  /// Repeat the selected span of ayahs.
  range,
}

/// Plays recitation.
///
/// Two paths, because al-Luhaidan publishes whole surahs: a verse-by-verse
/// reciter gets a gapless playlist of per-ayah files whose index is the
/// highlight, while a surah-by-surah reciter gets one source and no ayah
/// granularity at all.
class AudioPlayerService {
  AudioPlayerService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  /// Global ayah numbers in playing order. Empty for surah-by-surah playback,
  /// where individual ayahs are not addressable.
  List<int> _queue = const [];

  Stream<bool> get playing => _player.playingStream;
  Stream<Duration> get position => _player.positionStream;

  /// The global ayah number now sounding, or null when the reciter publishes
  /// whole surahs and there is nothing ayah-shaped to report.
  Stream<int?> get currentAyah =>
      _player.currentIndexStream.map((i) => ayahAt(_queue, i));

  /// Maps a playlist index onto the global ayah number it plays.
  ///
  /// Returns null for an empty queue (surah-by-surah playback) or an index that
  /// is out of range, which happens transiently while a new surah loads — the
  /// old index can arrive before the new queue does, and reading past the end
  /// there would highlight the wrong ayah.
  static int? ayahAt(List<int> queue, int? index) =>
      (index == null || index < 0 || index >= queue.length)
          ? null
          : queue[index];

  /// Queues [ayahNumbers] for a verse-by-verse reciter, or the whole surah file
  /// for a surah-by-surah one.
  Future<void> load({
    required Reciter reciter,
    required int surah,
    required List<int> ayahNumbers,
    int startAt = 0,
  }) async {
    if (reciter.isVerseByVerse) {
      _queue = ayahNumbers;
      await _player.setAudioSources(
        [for (final n in ayahNumbers) AudioSource.uri(AudioUrl.ayah(reciter, n))],
        initialIndex: startAt,
      );
    } else {
      _queue = const [];
      await _player.setAudioSource(
          AudioSource.uri(AudioUrl.surah(reciter, surah)));
    }
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();

  /// No-ops for a surah-by-surah reciter, which has no next ayah to seek to.
  Future<void> nextAyah() async {
    if (_queue.isEmpty) return;
    await _player.seekToNext();
  }

  Future<void> previousAyah() async {
    if (_queue.isEmpty) return;
    await _player.seekToPrevious();
  }

  Future<void> setRepeat(RepeatMode mode) => _player.setLoopMode(switch (mode) {
        RepeatMode.none => LoopMode.off,
        RepeatMode.ayah => LoopMode.one,
        RepeatMode.range => LoopMode.all,
      });

  Future<void> dispose() => _player.dispose();
}
