import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/ayah.dart';
import '../../domain/models/edition.dart';
import '../../domain/models/surah.dart';

class AlquranApiException implements Exception {
  AlquranApiException(this.message);
  final String message;
  @override
  String toString() => 'AlquranApiException: $message';
}

/// Wraps alquran.cloud. Holds no state; one service per data source.
class AlquranApiService {
  AlquranApiService({
    http.Client? client,
    this.baseUrl = defaultBase,
    this.timeout = defaultTimeout,
  }) : _client = client ?? http.Client();

  static const defaultBase = 'https://api.alquran.cloud/v1';

  /// Generous, because the whole-edition endpoint has a long tail: measured
  /// ~2 s typically but 38 s on one sampled request. Without a timeout a slow
  /// response hangs with no feedback at all.
  static const defaultTimeout = Duration(seconds: 60);

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  Future<dynamic> _get(String path) async {
    final http.Response response;
    try {
      response = await _client.get(Uri.parse('$baseUrl$path')).timeout(timeout);
    } on TimeoutException {
      throw AlquranApiException('GET $path timed out after ${timeout.inSeconds}s');
    }
    if (response.statusCode != 200) {
      throw AlquranApiException('GET $path returned ${response.statusCode}');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map || body['code'] != 200) {
      throw AlquranApiException('GET $path returned body code ${body is Map ? body['code'] : '?'}');
    }
    return body['data'];
  }

  /// Every text translation, for the language picker. All 48 languages.
  Future<List<Edition>> translationEditions() async {
    final data = await _get('/edition?format=text&type=translation') as List;
    return data
        .map((e) => Edition.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// The 114 surah names and metadata. ~19 KB — this is what paints first.
  Future<List<Surah>> surahs() async {
    final data = await _get('/surah') as List;
    return data
        .map((s) => Surah.fromJson(s as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Arabic, in the Uthmani script the app renders.
  static const arabicEdition = 'quran-uthmani';

  /// One ayah, in Arabic and in a translation, in a single request.
  ///
  /// 2.3 KB, and the whole of a day's network use. Each row carries its surah
  /// inline — number, name, ayah count — so nothing else has to be fetched or
  /// stored to render a citation.
  Future<({Ayah ayah, Surah surah, String? translation})> dailyAyah(
    int number,
    String? translationEdition,
  ) async {
    final editions = [
      arabicEdition,
      if (translationEdition != null && translationEdition != arabicEdition)
        translationEdition,
    ];
    final data = await _get('/ayah/$number/editions/${editions.join(',')}');

    // A single edition can come back unwrapped; asking for two always yields a
    // list. Both shapes are handled so the Arabic-only path cannot surprise.
    final rows = (data is List ? data : [data]).cast<Map<String, dynamic>>();

    Map<String, dynamic>? rowFor(String edition) {
      for (final row in rows) {
        if ((row['edition'] as Map)['identifier'] == edition) return row;
      }
      return null;
    }

    final arabic = rowFor(arabicEdition);
    if (arabic == null) {
      throw AlquranApiException('ayah $number came back without $arabicEdition');
    }

    final surah = Surah.fromJson(arabic['surah'] as Map<String, dynamic>);
    final translation = translationEdition == null
        ? null
        : rowFor(translationEdition)?['text'] as String?;

    return (
      ayah: Ayah.fromJson(arabic, surah.number),
      surah: surah,
      translation: translation,
    );
  }

  void close() => _client.close();
}
