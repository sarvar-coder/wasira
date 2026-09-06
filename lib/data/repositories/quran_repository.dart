import '../../domain/models/ayah.dart';
import '../../domain/models/edition.dart';
import '../../domain/models/surah.dart';
import '../services/alquran_api_service.dart';
import '../services/database_service.dart';

/// Source of truth for Quran text. Answers the one question the hybrid download
/// design turns on: *do I have this locally, or must I fetch it?*
///
/// The background sync fills the database over a few seconds. Until it lands,
/// reads fall through to the network so nothing blocks on it.
class QuranRepository {
  QuranRepository({required this.db, required this.api});

  final DatabaseService db;
  final AlquranApiService api;

  static const arabicEdition = 'quran-uthmani';

  /// The 114 surahs. Served from the database once synced; otherwise fetched
  /// (19 KB) and cached, because this is what paints first.
  Future<List<Surah>> surahs() async {
    final local = db.readSurahs();
    if (local.isNotEmpty) return local;

    final fetched = await api.surahs();
    db.writeSurahs(fetched);
    return fetched;
  }

  /// Arabic ayahs for one surah. Falls back to fetching just that surah
  /// (247 KB worst case) when the background sync has not reached it.
  Future<List<Ayah>> ayahs(int surah) async {
    final local = db.readAyahs(surah);
    if (local.isNotEmpty) return local;

    final fetched = await api.surah(surah, arabicEdition);
    db.writeSurahs(fetched.surahs);
    db.writeAyahs(fetched.ayahs);
    return fetched.ayahs;
  }

  /// Translations for one surah, keyed by global ayah number. Empty when the
  /// user reads Arabic only.
  Future<Map<int, String>> translations(int surah, String? edition) async {
    if (edition == null) return const {};

    final local = db.readTranslations(surah, edition);
    if (local.isNotEmpty) return local;

    final fetched = await api.surah(surah, edition);
    final texts = {for (final a in fetched.ayahs) a.number: a.textAr};
    db.writeTranslations(edition, texts);
    return texts;
  }

  /// Every text translation the API offers, for the language picker.
  /// Cached after the first call so the picker reopens instantly.
  Future<List<Edition>> translationEditions() async {
    final local = db.readEditions(format: 'text', type: 'translation');
    if (local.isNotEmpty) return local;

    final fetched = await api.translationEditions();
    for (final e in fetched) {
      db.writeEdition(e);
    }
    return fetched;
  }

  /// Ayahs by global number, for the daily pick. Local only: the numbers are
  /// scattered across the Quran, and fetching them would mean one whole-surah
  /// request each. Returns fewer than asked for while the sync is still
  /// running, which is how the daily screen knows to wait.
  List<Ayah> ayahsByNumber(List<int> numbers) => db.readAyahsByNumber(numbers);

  Map<int, String> translationsByNumber(List<int> numbers, String? edition) =>
      edition == null
          ? const {}
          : db.readTranslationsByNumber(numbers, edition);

  bool get isSynced => db.hasEdition(arabicEdition);
}
