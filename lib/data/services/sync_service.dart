import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import 'alquran_api_service.dart';
import 'database_service.dart';

/// Downloads a whole edition and writes it to the database.
///
/// The work runs on a spawned isolate because it parses 2–3 MB of JSON and
/// writes 6236 rows. On the UI isolate that janks; the surah list must stay
/// scrollable while this runs.
class SyncService {
  const SyncService();

  /// Emits progress in 0..1, then closes. Throws if the isolate reports failure.
  Stream<double> syncEdition({
    required String dbPath,
    required String editionId,
    required bool isArabic,
    String baseUrl = AlquranApiService.defaultBase,
  }) async* {
    final port = ReceivePort();
    final isolate = await Isolate.spawn(
      _worker,
      _Request(port.sendPort, dbPath, editionId, isArabic, baseUrl),
    );

    try {
      await for (final message in port) {
        switch (message) {
          case double progress:
            yield progress;
          case _Failure(:final error):
            throw AlquranApiException(error);
          case _Done():
            return;
        }
      }
    } finally {
      port.close();
      isolate.kill(priority: Isolate.immediate);
    }
  }
}

class _Request {
  const _Request(
      this.reply, this.dbPath, this.editionId, this.isArabic, this.baseUrl);
  final SendPort reply;
  final String dbPath;
  final String editionId;
  final bool isArabic;
  final String baseUrl;
}

class _Done {
  const _Done();
}

class _Failure {
  const _Failure(this.error);
  final String error;
}

Future<void> _worker(_Request request) async {
  final api = AlquranApiService(baseUrl: request.baseUrl);
  final db = sqlite3.open(request.dbPath);
  try {
    final service = DatabaseService(db)..migrate();
    await syncEditionInto(
      db: service,
      api: api,
      editionId: request.editionId,
      isArabic: request.isArabic,
      onProgress: request.reply.send,
    );
    request.reply.send(const _Done());
  } catch (error) {
    request.reply.send(_Failure(error.toString()));
  } finally {
    db.close();
    api.close();
  }
}

/// The actual work, isolate-free so it can be tested against an in-memory
/// database and a mocked client.
///
/// [isArabic] selects where the text lands: the Arabic edition fills `ayahs`
/// and their structural metadata, a translation fills `translations`.
Future<void> syncEditionInto({
  required DatabaseService db,
  required AlquranApiService api,
  required String editionId,
  required bool isArabic,
  required void Function(double) onProgress,
}) async {
  onProgress(0);
  final edition = await api.wholeEdition(editionId);
  onProgress(0.6); // the download dominates; writing is comparatively cheap

  db.writeSurahs(edition.surahs);
  onProgress(0.75);

  if (isArabic) {
    db.writeAyahs(edition.ayahs);
  } else {
    db.writeTranslations(
      editionId,
      {for (final a in edition.ayahs) a.number: a.textAr},
    );
  }
  onProgress(1);
}
