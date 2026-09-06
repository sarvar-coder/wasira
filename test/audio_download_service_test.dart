import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wasira/data/services/audio_download_service.dart';
import 'package:wasira/domain/reciter.dart';

/// Counts requests and reports the high-water mark of overlapping ones, which
/// is the only way to see the concurrency cap actually hold.
class _FakeCdn extends http.BaseClient {
  _FakeCdn({this.failOn = const {}});

  /// Stands in for an mp3. Only its length matters, to the size assertions.
  static const body = [1, 2, 3];

  /// Numbers whose request 404s, as `<edition>/<number>`.
  final Set<String> failOn;

  final requested = <Uri>[];
  int inFlight = 0;
  int peakInFlight = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requested.add(request.url);
    inFlight++;
    peakInFlight = inFlight > peakInFlight ? inFlight : peakInFlight;

    // Yields so every worker that can start has started before any finishes;
    // without this the cap would look held even if it were not.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    inFlight--;

    final key = request.url.pathSegments.reversed.take(2).toList().reversed.join('/');
    if (failOn.contains(key)) {
      return http.StreamedResponse(const Stream.empty(), 404);
    }
    return http.StreamedResponse(Stream.value(body), 200,
        contentLength: body.length);
  }
}

void main() {
  late Directory root;
  late _FakeCdn cdn;
  late AudioDownloadService service;

  // Al-Fatiha: global ayah numbers 1..7.
  const fatiha = [1, 2, 3, 4, 5, 6, 7];

  setUp(() {
    root = Directory.systemTemp.createTempSync('wasira_audio');
    cdn = _FakeCdn();
    service = AudioDownloadService(root: root, client: cdn);
  });

  tearDown(() => root.deleteSync(recursive: true));

  group('what a surah costs', () {
    test('a verse-by-verse reciter needs one file per ayah', () {
      expect(service.targets(Reciter.alafasy, 1, fatiha), fatiha);
    });

    test('a surah-by-surah reciter needs exactly one', () {
      expect(service.targets(Reciter.luhaidan, 1, fatiha), [1]);
    });
  });

  group('downloading', () {
    test('fetches every ayah of a verse-by-verse surah', () async {
      await service.download(Reciter.alafasy, 1, fatiha);

      expect(cdn.requested, hasLength(7));
      for (final n in fatiha) {
        expect(service.has(Reciter.alafasy, n), isTrue);
      }
    });

    test('fetches the one surah file for al-Luhaidan', () async {
      await service.download(Reciter.luhaidan, 1, fatiha);

      expect(cdn.requested.single.path,
          '/quran/audio-surah/128/ar.muhammadalluhaidan/1.mp3');
      expect(service.has(Reciter.luhaidan, 1), isTrue);
    });

    test('never runs more than 4 requests at once', () async {
      // Al-Baqarah is 286 files. Firing them all at a free keyless CDN is what
      // the cap exists to prevent.
      final baqarah = [for (var n = 8; n <= 293; n++) n];
      await service.download(Reciter.alafasy, 2, baqarah);

      expect(cdn.requested, hasLength(286));
      expect(cdn.peakInFlight, lessThanOrEqualTo(AudioDownloadService.maxConcurrent));
      expect(cdn.peakInFlight, AudioDownloadService.maxConcurrent,
          reason: 'a lower peak would mean the workers are not parallel at all');
    });

    test('two surahs asked for at once still share the four-request cap',
        () async {
      // The screen can be left and re-entered mid-download, so more than one
      // caller can be queueing surahs. The cap is per service, not per call.
      await Future.wait([
        service.download(Reciter.alafasy, 1, fatiha),
        service.download(Reciter.alafasy, 2, [for (var n = 8; n <= 60; n++) n]),
      ]);

      expect(cdn.requested, hasLength(7 + 53));
      expect(cdn.peakInFlight,
          lessThanOrEqualTo(AudioDownloadService.maxConcurrent));
    });

    test('resumes by skipping what is already on disk', () async {
      await service.download(Reciter.alafasy, 1, fatiha);
      cdn.requested.clear();

      service.fileFor(Reciter.alafasy, 4).deleteSync();
      await service.download(Reciter.alafasy, 1, fatiha);

      expect(cdn.requested.single.path, endsWith('/ar.alafasy/4.mp3'));
    });

    test('reports progress over the whole surah, not the missing part',
        () async {
      await service.download(Reciter.alafasy, 1, fatiha);
      service.fileFor(Reciter.alafasy, 7).deleteSync();

      final seen = <(int, int)>[];
      await service.download(Reciter.alafasy, 1, fatiha,
          onProgress: (done, total) => seen.add((done, total)));

      // A resumed download starts at 6 of 7 rather than 0 of 1.
      expect(seen, [(6, 7), (7, 7)]);
    });
  });

  group('a failed fetch', () {
    setUp(() {
      cdn = _FakeCdn(failOn: {'ar.alafasy/3.mp3'});
      service = AudioDownloadService(root: root, client: cdn);
    });

    test('throws rather than reporting the surah complete', () async {
      await expectLater(
          service.download(Reciter.alafasy, 1, fatiha), throwsA(anything));
    });

    test('does not poison the surah queued behind it', () async {
      await service.download(Reciter.alafasy, 1, fatiha).catchError((_) {});
      // Al-Ikhlas, whose files are fine, must still download.
      await service.download(Reciter.alafasy, 112, [6222, 6223, 6224, 6225]);

      expect(service.progress(Reciter.alafasy, 112, [6222, 6223, 6224, 6225]),
          (4, 4));
    });

    test('leaves nothing the resume check would mistake for a finished file',
        () async {
      await service.download(Reciter.alafasy, 1, fatiha).catchError((_) {});

      // A truncated mp3 at the real path would pass `has` and then play as
      // silence, which is worse than failing outright.
      expect(service.has(Reciter.alafasy, 3), isFalse);
      expect(
          service
              .dirFor(Reciter.alafasy)
              .listSync()
              .where((f) => f.path.endsWith('.part')),
          isEmpty);
    });
  });

  group('playing what was downloaded', () {
    test('reads the local file once it exists', () async {
      expect(service.sourceFor(Reciter.alafasy, 1).scheme, 'https');

      await service.download(Reciter.alafasy, 1, fatiha);

      expect(service.sourceFor(Reciter.alafasy, 1).scheme, 'file');
      expect(service.sourceFor(Reciter.alafasy, 1).path,
          service.fileFor(Reciter.alafasy, 1).uri.path);
    });

    test('falls back to the CDN for an ayah that was never downloaded',
        () async {
      await service.download(Reciter.alafasy, 1, fatiha);

      expect(service.sourceFor(Reciter.alafasy, 500).toString(),
          'https://cdn.islamic.network/quran/audio/128/ar.alafasy/500.mp3');
    });
  });

  group('managing disk', () {
    test('reports size and progress per surah', () async {
      await service.download(Reciter.alafasy, 1, fatiha);

      expect(service.bytesFor(Reciter.alafasy, 1, fatiha), 7 * 3);
      expect(service.progress(Reciter.alafasy, 1, fatiha), (7, 7));
    });

    test('a half-downloaded surah reports what it has', () async {
      await service.download(Reciter.alafasy, 1, fatiha);
      service.fileFor(Reciter.alafasy, 1).deleteSync();
      service.fileFor(Reciter.alafasy, 2).deleteSync();

      expect(service.progress(Reciter.alafasy, 1, fatiha), (5, 7));
      expect(service.bytesFor(Reciter.alafasy, 1, fatiha), 5 * 3);
    });

    test('deleting reclaims the surah and leaves the reciter usable', () async {
      await service.download(Reciter.alafasy, 1, fatiha);
      service.delete(Reciter.alafasy, 1, fatiha);

      expect(service.progress(Reciter.alafasy, 1, fatiha), (0, 7));
      expect(service.bytesFor(Reciter.alafasy, 1, fatiha), 0);
      // Deleted audio streams again rather than failing.
      expect(service.sourceFor(Reciter.alafasy, 1).scheme, 'https');
    });

    test('deleting a surah that was never downloaded is not an error', () {
      expect(() => service.delete(Reciter.alafasy, 1, fatiha), returnsNormally);
    });
  });
}
