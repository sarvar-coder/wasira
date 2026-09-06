import '../../domain/reciter.dart';

sealed class DownloadsEvent {}

class DownloadsRequested extends DownloadsEvent {}

/// Picks whose downloads are being managed. Deliberately does **not** change
/// the reciter the reader plays: reclaiming disk from one reciter should not
/// silently swap the voice in the audio bar.
class DownloadsReciterChanged extends DownloadsEvent {
  DownloadsReciterChanged(this.reciter);
  final Reciter reciter;
}

class SurahDownloadRequested extends DownloadsEvent {
  SurahDownloadRequested(this.surah);
  final int surah;
}

class SurahDownloadDeleted extends DownloadsEvent {
  SurahDownloadDeleted(this.surah);
  final int surah;
}

/// Raised by the bloc itself as files land. Carries [reciter] because a
/// download outlives a change of picker and must not repaint another
/// reciter's row.
class SurahDownloadProgressed extends DownloadsEvent {
  SurahDownloadProgressed(this.reciter, this.surah, this.done, this.total);
  final Reciter reciter;
  final int surah;
  final int done;
  final int total;
}

class SurahDownloadSettled extends DownloadsEvent {
  SurahDownloadSettled(this.reciter, this.surah, {this.error});
  final Reciter reciter;
  final int surah;
  final Object? error;
}
