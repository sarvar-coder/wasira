/// A text or audio edition. `type` selects the audio playback path and
/// `bitrate` is per-reciter, because 128k is not universally available.
class Edition {
  const Edition({
    required this.identifier,
    required this.language,
    required this.name,
    required this.englishName,
    required this.format,
    required this.type,
    required this.direction,
    this.bitrate,
  });

  final String identifier;
  final String language;
  final String name;
  final String englishName;

  /// `text` or `audio`.
  final String format;

  /// `quran`, `translation`, `versebyverse`, `surahbysurah`, `tafsir`, ...
  final String type;

  /// `rtl` or `ltr`, supplied by the API. Drives translation text direction.
  final String? direction;

  final int? bitrate;

  bool get isSurahBySurah => type == 'surahbysurah';

  factory Edition.fromJson(Map<String, dynamic> json) => Edition(
        identifier: json['identifier'] as String,
        language: json['language'] as String,
        name: json['name'] as String,
        englishName: json['englishName'] as String,
        format: json['format'] as String,
        type: json['type'] as String,
        direction: json['direction'] as String?,
      );
}
