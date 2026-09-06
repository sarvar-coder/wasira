import '../../domain/models/surah.dart';
import '../../domain/reciter.dart';

sealed class DownloadsState {}

class DownloadsLoading extends DownloadsState {}

class DownloadsFailed extends DownloadsState {
  DownloadsFailed(this.error);
  final Object error;
}

class DownloadsLoaded extends DownloadsState {
  DownloadsLoaded({required this.reciter, required this.rows});

  final Reciter reciter;
  final List<SurahDownload> rows;

  int get bytes => rows.fold(0, (sum, row) => sum + row.bytes);

  DownloadsLoaded replacing(SurahDownload row) => DownloadsLoaded(
        reciter: reciter,
        rows: [
          for (final r in rows) r.surah.number == row.surah.number ? row : r
        ],
      );

  SurahDownload? rowFor(int surah) {
    for (final row in rows) {
      if (row.surah.number == surah) return row;
    }
    return null;
  }
}

/// One surah's audio for one reciter.
class SurahDownload {
  const SurahDownload({
    required this.surah,
    required this.ayahNumbers,
    required this.done,
    required this.total,
    required this.bytes,
    this.downloading = false,
    this.error,
  });

  final Surah surah;

  /// Global ayah numbers, which is what the download service addresses files
  /// by. Held here so a row can be handed straight to it.
  final List<int> ayahNumbers;

  /// Files on disk out of files needed. For a surah-by-surah reciter [total]
  /// is 1 — a single 55 MB file for Al-Baqarah.
  final int done;
  final int total;

  final int bytes;
  final bool downloading;
  final Object? error;

  bool get complete => done == total;

  /// Started but interrupted. Worth showing distinctly: tapping download again
  /// resumes rather than starting over.
  bool get partial => done > 0 && !complete;

  SurahDownload copyWith({
    int? done,
    int? total,
    int? bytes,
    bool? downloading,
    Object? error,
    bool clearError = false,
  }) =>
      SurahDownload(
        surah: surah,
        ayahNumbers: ayahNumbers,
        done: done ?? this.done,
        total: total ?? this.total,
        bytes: bytes ?? this.bytes,
        downloading: downloading ?? this.downloading,
        error: clearError ? null : (error ?? this.error),
      );
}
