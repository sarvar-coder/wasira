import 'package:flutter_test/flutter_test.dart';
import 'package:wasira/domain/audio_url.dart';
import 'package:wasira/domain/reciter.dart';

void main() {
  group('the offered reciters', () {
    test('are exactly three, all Arabic recitation', () {
      expect(Reciter.all, hasLength(3));
      expect(Reciter.all.map((r) => r.edition), [
        'ar.alafasy',
        'ar.husarymujawwad',
        'ar.muhammadalluhaidan',
      ]);
    });

    test('never include a reading of a translation', () {
      // The API offers 14 non-Arabic audio editions. uz.sodik-audio is one of
      // them: someone reading the Uzbek translation aloud, which is not
      // recitation and must never appear as a reciter.
      const notRecitation = [
        'uz.sodik-audio',
        'ru.kuliev-audio',
        'en.walk',
        'ur.khan',
      ];
      for (final edition in notRecitation) {
        expect(Reciter.all.any((r) => r.edition == edition), isFalse,
            reason: '$edition is a translation reading, not recitation');
      }
    });
  });

  group('verse-by-verse URLs', () {
    test('address an ayah by its global number', () {
      expect(
        AudioUrl.ayah(Reciter.alafasy, 1).toString(),
        'https://cdn.islamic.network/quran/audio/128/ar.alafasy/1.mp3',
      );
      expect(
        AudioUrl.ayah(Reciter.alafasy, 6236).toString(),
        'https://cdn.islamic.network/quran/audio/128/ar.alafasy/6236.mp3',
      );
    });

    test('use the reciter own bitrate rather than a literal', () {
      for (final reciter in Reciter.all.where((r) => r.isVerseByVerse)) {
        expect(AudioUrl.ayah(reciter, 1).toString(),
            contains('/${reciter.bitrate}/'));
      }
    });

    test('reject an ayah number outside 1..6236', () {
      expect(() => AudioUrl.ayah(Reciter.alafasy, 0), throwsRangeError);
      expect(() => AudioUrl.ayah(Reciter.alafasy, 6237), throwsRangeError);
    });

    test('refuse a surah-by-surah reciter', () {
      expect(() => AudioUrl.ayah(Reciter.luhaidan, 1), throwsArgumentError);
    });
  });

  group('surah-by-surah URLs', () {
    test('use the audio-surah path and a surah number', () {
      expect(
        AudioUrl.surah(Reciter.luhaidan, 1).toString(),
        'https://cdn.islamic.network/quran/audio-surah/128/ar.muhammadalluhaidan/1.mp3',
      );
      expect(
        AudioUrl.surah(Reciter.luhaidan, 114).toString(),
        'https://cdn.islamic.network/quran/audio-surah/128/ar.muhammadalluhaidan/114.mp3',
      );
    });

    test('are a different path from verse-by-verse, not just a different id',
        () {
      expect(AudioUrl.surah(Reciter.luhaidan, 1).path, contains('/audio-surah/'));
      expect(AudioUrl.ayah(Reciter.alafasy, 1).path, isNot(contains('audio-surah')));
    });

    test('reject a surah number outside 1..114', () {
      expect(() => AudioUrl.surah(Reciter.luhaidan, 0), throwsRangeError);
      expect(() => AudioUrl.surah(Reciter.luhaidan, 115), throwsRangeError);
    });

    test('refuse a verse-by-verse reciter', () {
      expect(() => AudioUrl.surah(Reciter.alafasy, 1), throwsArgumentError);
    });
  });

  group('ayah-level capability', () {
    test('follows the layout, so it cannot be set wrongly by hand', () {
      expect(Reciter.alafasy.supportsAyahControls, isTrue);
      expect(Reciter.husaryMujawwad.supportsAyahControls, isTrue);
      expect(Reciter.luhaidan.supportsAyahControls, isFalse);
    });
  });
}
