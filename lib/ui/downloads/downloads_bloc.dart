import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/quran_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/audio_download_service.dart';
import '../../domain/ayah_numbering.dart';
import '../../domain/models/surah.dart';
import '../../domain/reciter.dart';
import 'downloads_event.dart';
import 'downloads_state.dart';

/// Manages recitation on disk: what is downloaded, how much room it takes, and
/// getting it back.
class DownloadsBloc extends Bloc<DownloadsEvent, DownloadsState> {
  DownloadsBloc({
    required this.repository,
    required this.downloads,
    required SettingsRepository settings,
  })  : _reciter = settings.reciter,
        super(DownloadsLoading()) {
    on<DownloadsRequested>(_onRequested);
    on<DownloadsReciterChanged>(_onReciterChanged);
    on<SurahDownloadRequested>(_onDownload);
    on<SurahDownloadDeleted>(_onDelete);
    on<SurahDownloadProgressed>(_onProgressed);
    on<SurahDownloadSettled>(_onSettled);
  }

  final QuranRepository repository;
  final AudioDownloadService downloads;

  /// Opens on whoever the reader is playing, then follows this screen's own
  /// picker.
  Reciter _reciter;

  List<Surah> _surahs = const [];
  Map<int, List<int>> _ayahNumbers = const {};

  Future<void> _onRequested(
      DownloadsRequested event, Emitter<DownloadsState> emit) async {
    emit(DownloadsLoading());
    try {
      _surahs = await repository.surahs();
      _ayahNumbers = ayahNumbersBySurah(_surahs);
      emit(_scan(_reciter));
    } catch (error) {
      emit(DownloadsFailed(error));
    }
  }

  void _onReciterChanged(
      DownloadsReciterChanged event, Emitter<DownloadsState> emit) {
    _reciter = event.reciter;
    if (state is DownloadsLoaded) emit(_scan(_reciter));
  }

  /// Reads the filesystem for every surah. 6236 stats for a verse-by-verse
  /// reciter, which is milliseconds and keeps disk as the single record of
  /// what is downloaded.
  DownloadsLoaded _scan(Reciter reciter) {
    final inFlight = switch (state) {
      DownloadsLoaded(:final rows) when reciter.edition == _reciter.edition =>
        {for (final r in rows.where((r) => r.downloading)) r.surah.number},
      _ => <int>{},
    };

    return DownloadsLoaded(
      reciter: reciter,
      rows: [
        for (final surah in _surahs)
          _row(reciter, surah, downloading: inFlight.contains(surah.number)),
      ],
    );
  }

  SurahDownload _row(Reciter reciter, Surah surah, {bool downloading = false}) {
    final numbers = _ayahNumbers[surah.number] ?? const <int>[];
    final (done, total) = downloads.progress(reciter, surah.number, numbers);
    return SurahDownload(
      surah: surah,
      ayahNumbers: numbers,
      done: done,
      total: total,
      bytes: downloads.bytesFor(reciter, surah.number, numbers),
      downloading: downloading,
    );
  }

  void _onDownload(
      SurahDownloadRequested event, Emitter<DownloadsState> emit) {
    if (state case final DownloadsLoaded loaded) {
      final row = loaded.rowFor(event.surah);
      if (row == null || row.downloading || row.complete) return;

      emit(loaded
          .replacing(row.copyWith(downloading: true, clearError: true)));

      // Captured rather than read later: the picker can move on while this
      // download is still queued.
      // Unawaited: the service queues surahs itself, so several can be asked
      // for at once and they still arrive one at a time.
      final reciter = loaded.reciter;
      downloads
          .download(
            reciter,
            row.surah.number,
            row.ayahNumbers,
            onProgress: (done, total) => _raise(
                SurahDownloadProgressed(reciter, row.surah.number, done, total)),
          )
          .then((_) => _raise(SurahDownloadSettled(reciter, row.surah.number)))
          .catchError((Object error) =>
              _raise(SurahDownloadSettled(reciter, row.surah.number, error: error)));
    }
  }

  /// A download outlives the screen that started it, so a late event has
  /// nowhere to go.
  void _raise(DownloadsEvent event) {
    if (!isClosed) add(event);
  }

  void _onProgressed(
      SurahDownloadProgressed event, Emitter<DownloadsState> emit) {
    if (state case final DownloadsLoaded loaded) {
      if (loaded.reciter.edition != event.reciter.edition) return;
      final row = loaded.rowFor(event.surah);
      if (row == null) return;
      emit(loaded.replacing(row.copyWith(done: event.done, total: event.total)));
    }
  }

  /// Re-reads the row from disk rather than trusting the counter, so the size
  /// shown is the size actually occupied — including a download that failed
  /// partway and kept what it did fetch.
  void _onSettled(SurahDownloadSettled event, Emitter<DownloadsState> emit) {
    if (state case final DownloadsLoaded loaded) {
      if (loaded.reciter.edition != event.reciter.edition) return;
      final row = loaded.rowFor(event.surah);
      if (row == null) return;
      emit(loaded.replacing(
          _row(loaded.reciter, row.surah).copyWith(error: event.error)));
    }
  }

  void _onDelete(SurahDownloadDeleted event, Emitter<DownloadsState> emit) {
    if (state case final DownloadsLoaded loaded) {
      final row = loaded.rowFor(event.surah);
      // A download in flight would immediately rewrite what was deleted.
      if (row == null || row.downloading) return;

      downloads.delete(loaded.reciter, row.surah.number, row.ayahNumbers);
      emit(loaded.replacing(_row(loaded.reciter, row.surah)));
    }
  }
}
