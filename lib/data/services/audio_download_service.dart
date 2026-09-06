import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/audio_url.dart';
import '../../domain/reciter.dart';

/// Downloads recitation so a reciter can be listened to offline.
///
/// Al-Baqarah is 286 separate files for a verse-by-verse reciter, around
/// 100 MB, and one 55 MB file for al-Luhaidan. alquran.cloud and
/// islamic.network are free and keyless, so [maxConcurrent] is a courtesy cap
/// rather than a tuning knob: 286 parallel requests would be abusive and get
/// rate-limited.
class AudioDownloadService {
  AudioDownloadService({required this.root, http.Client? client})
      : _client = client ?? http.Client();

  /// The app's own support directory. Audio lives under `audio/<edition>/`.
  final Directory root;
  final http.Client _client;

  static const maxConcurrent = 4;

  Directory dirFor(Reciter reciter) =>
      Directory('${root.path}/audio/${reciter.edition}');

  /// [number] is a **global ayah number** for a verse-by-verse reciter and a
  /// **surah number** for a surah-by-surah one. A reciter is only ever one of
  /// the two, so the two numbering spaces never share a directory.
  File fileFor(Reciter reciter, int number) =>
      File('${dirFor(reciter).path}/$number.mp3');

  /// Every file this reciter needs for [surah]: one per ayah, or one for the
  /// whole surah.
  List<int> targets(Reciter reciter, int surah, List<int> ayahNumbers) =>
      reciter.isVerseByVerse ? ayahNumbers : [surah];

  /// Resume is this check and nothing else — no state machine, no partial-file
  /// bookkeeping, because [_fetch] only ever renames a whole file into place.
  bool has(Reciter reciter, int number) => fileFor(reciter, number).existsSync();

  /// What the player should read: the local copy when it exists, the CDN
  /// otherwise. This is the point of downloading at all.
  Uri sourceFor(Reciter reciter, int number) {
    final file = fileFor(reciter, number);
    return file.existsSync() ? file.uri : AudioUrl.of(reciter, number);
  }

  /// How many of this surah's files are already on disk, out of how many.
  ///
  // ponytail: the filesystem is the only record. Schema v1 has an
  // `audio_downloads` table for the same counts, but two sources drift; drop
  // the table in a later migration if nothing claims it.
  (int done, int total) progress(
      Reciter reciter, int surah, List<int> ayahNumbers) {
    final all = targets(reciter, surah, ayahNumbers);
    return (all.where((n) => has(reciter, n)).length, all.length);
  }

  /// Bytes this surah occupies for this reciter.
  int bytesFor(Reciter reciter, int surah, List<int> ayahNumbers) {
    var bytes = 0;
    for (final n in targets(reciter, surah, ayahNumbers)) {
      final file = fileFor(reciter, n);
      if (file.existsSync()) bytes += file.lengthSync();
    }
    return bytes;
  }

  void delete(Reciter reciter, int surah, List<int> ayahNumbers) {
    for (final n in targets(reciter, surah, ayahNumbers)) {
      final file = fileFor(reciter, n);
      if (file.existsSync()) file.deleteSync();
    }
  }

  /// Fetches whatever [surah] is still missing, at most [maxConcurrent]
  /// requests at a time. Already-downloaded files are skipped, so calling this
  /// again after an interruption resumes.
  ///
  /// [onProgress] fires with (done, total) counted over the whole surah, not
  /// only the missing part, so a resumed download does not restart the bar
  /// at zero.
  ///
  /// Surahs are downloaded one after another. The cap is per service, not per
  /// call: two screens each asking for a surah must still add up to four
  /// requests, so queueing here is what keeps [maxConcurrent] honest.
  Future<void> download(
    Reciter reciter,
    int surah,
    List<int> ayahNumbers, {
    void Function(int done, int total)? onProgress,
  }) {
    final result = _queue.then((_) =>
        _download(reciter, surah, ayahNumbers, onProgress: onProgress));
    // The queue swallows the failure it hands the caller; one bad surah must
    // not poison every surah asked for after it.
    _queue = result.catchError((Object _) {});
    return result;
  }

  Future<void> _queue = Future.value();

  Future<void> _download(
    Reciter reciter,
    int surah,
    List<int> ayahNumbers, {
    void Function(int done, int total)? onProgress,
  }) async {
    await dirFor(reciter).create(recursive: true);

    final all = targets(reciter, surah, ayahNumbers);
    final missing = [for (final n in all) if (!has(reciter, n)) n];
    var done = all.length - missing.length;
    var next = 0;
    onProgress?.call(done, all.length);

    // One isolate, so the cursor needs no lock: nothing awaits between reading
    // `next` and incrementing it.
    Object? failure;
    Future<void> worker() async {
      while (next < missing.length && failure == null) {
        try {
          await _fetch(reciter, missing[next++]);
        } catch (error) {
          failure = error;
          rethrow;
        }
        onProgress?.call(++done, all.length);
      }
    }

    // Deliberately not `eagerError`: the first failure stops the queue through
    // [failure], but a sibling already mid-write has to finish and clean up its
    // own `.part` file before this returns. Returning early would hand the
    // caller a directory that is still being written to.
    await Future.wait([for (var i = 0; i < maxConcurrent; i++) worker()]);
  }

  /// Streams to a `.part` file and renames on success.
  ///
  /// A truncated mp3 left at the real path would pass the resume check and then
  /// play as silence, which is worse than failing: al-Luhaidan's Al-Baqarah is
  /// one 55 MB file, so half of it is 20 minutes of nothing.
  Future<void> _fetch(Reciter reciter, int number) async {
    final url = AudioUrl.of(reciter, number);
    final target = fileFor(reciter, number);
    final part = File('${target.path}.part');

    try {
      final response = await _client.send(http.Request('GET', url));
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}', uri: url);
      }
      await response.stream.pipe(part.openWrite());
      await part.rename(target.path);
    } catch (_) {
      if (part.existsSync()) part.deleteSync();
      rethrow;
    }
  }

  void dispose() => _client.close();
}
