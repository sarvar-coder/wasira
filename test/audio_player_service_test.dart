import 'package:flutter_test/flutter_test.dart';
import 'package:wasira/data/services/audio_player_service.dart';

/// just_audio's player cannot be faked in a unit test, so what is asserted here
/// is the logic around it. Playback itself is verified by running the app.
void main() {
  group('mapping a playlist index onto an ayah', () {
    // Al-Fatiha: global ayah numbers 1..7.
    const queue = [1, 2, 3, 4, 5, 6, 7];

    test('an index resolves to the global ayah number, not the index', () {
      expect(AudioPlayerService.ayahAt(queue, 0), 1);
      expect(AudioPlayerService.ayahAt(queue, 6), 7);
    });

    test('a mid-Quran surah maps to its own global numbers', () {
      // Al-Baqarah starts at global ayah 8.
      const baqarah = [8, 9, 10];
      expect(AudioPlayerService.ayahAt(baqarah, 0), 8);
      expect(AudioPlayerService.ayahAt(baqarah, 2), 10);
    });

    test('a surah-by-surah reciter has no ayah to report', () {
      expect(AudioPlayerService.ayahAt(const [], 0), isNull);
      expect(AudioPlayerService.ayahAt(const [], null), isNull);
    });

    test('an index past the queue reports nothing rather than the wrong ayah',
        () {
      // This happens while switching surahs: the previous index can arrive
      // before the new queue does.
      expect(AudioPlayerService.ayahAt(queue, 7), isNull);
      expect(AudioPlayerService.ayahAt(queue, 999), isNull);
      expect(AudioPlayerService.ayahAt(queue, -1), isNull);
    });

    test('no index means nothing is sounding', () {
      expect(AudioPlayerService.ayahAt(queue, null), isNull);
    });
  });

  group('repeat modes', () {
    test('cover the memorization loop', () {
      // Repeating one ayah, then a span, is how hifz works.
      expect(RecitationRepeat.values,
          containsAll([RecitationRepeat.none, RecitationRepeat.ayah, RecitationRepeat.range]));
    });
  });
}
