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

  /// A whole edition in one request: ~2.1 MB for Arabic, ~3.2 MB for a
  /// translation. Parsing this belongs off the UI isolate.
  Future<({List<Surah> surahs, List<Ayah> ayahs})> wholeEdition(
      String identifier) async {
    final data = await _get('/quran/$identifier') as Map<String, dynamic>;
    return _parseSurahs(data['surahs'] as List);
  }

  /// One surah, the fallback when the background sync has not reached it yet.
  /// 247 KB worst case (Al-Baqarah in a tafsir-translation).
  Future<({List<Surah> surahs, List<Ayah> ayahs})> surah(
      int number, String identifier) async {
    final data = await _get('/surah/$number/$identifier') as Map<String, dynamic>;
    return _parseSurahs([data]);
  }

  static ({List<Surah> surahs, List<Ayah> ayahs}) _parseSurahs(List raw) {
    final surahs = <Surah>[];
    final ayahs = <Ayah>[];
    for (final s in raw.cast<Map<String, dynamic>>()) {
      surahs.add(Surah.fromJson(s));
      final number = s['number'] as int;
      for (final a in (s['ayahs'] as List).cast<Map<String, dynamic>>()) {
        ayahs.add(Ayah.fromJson(a, number));
      }
    }
    return (surahs: surahs, ayahs: ayahs);
  }

  void close() => _client.close();
}
