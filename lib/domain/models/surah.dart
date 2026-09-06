class Surah {
  const Surah({
    required this.number,
    required this.nameAr,
    required this.nameEn,
    required this.nameEnTranslation,
    required this.revelationType,
    required this.ayahCount,
  });

  final int number;
  final String nameAr;
  final String nameEn;
  final String nameEnTranslation;
  final String revelationType;
  final int ayahCount;

  factory Surah.fromJson(Map<String, dynamic> json) => Surah(
        number: json['number'] as int,
        nameAr: json['name'] as String,
        nameEn: json['englishName'] as String,
        nameEnTranslation: json['englishNameTranslation'] as String,
        revelationType: json['revelationType'] as String,
        ayahCount: (json['numberOfAyahs'] ?? (json['ayahs'] as List).length) as int,
      );
}
