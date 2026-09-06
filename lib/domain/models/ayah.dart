class Ayah {
  const Ayah({
    required this.number,
    required this.surah,
    required this.numberInSurah,
    required this.juz,
    required this.page,
    required this.hizbQuarter,
    required this.ruku,
    required this.manzil,
    required this.sajda,
    required this.sajdaObligatory,
    required this.textAr,
  });

  /// 1..6236, unique across the whole Quran. Also the audio file name for
  /// verse-by-verse reciters.
  final int number;
  final int surah;
  final int numberInSurah;
  final int juz;
  final int page;
  final int hizbQuarter;
  final int ruku;
  final int manzil;

  /// One of the 15 ayahs of prostration. The reader marks these with ۩.
  final bool sajda;

  /// The API's classification: 4 of the 15 are obligatory, 11 recommended.
  /// Stored as given rather than interpreted — which sajdas are obligatory
  /// varies by madhhab, so this is data, not a ruling. Null when not a sajda.
  final bool? sajdaObligatory;
  final String textAr;

  factory Ayah.fromJson(Map<String, dynamic> json, int surahNumber) => Ayah(
        number: json['number'] as int,
        surah: surahNumber,
        numberInSurah: json['numberInSurah'] as int,
        juz: json['juz'] as int,
        page: json['page'] as int,
        hizbQuarter: json['hizbQuarter'] as int,
        ruku: json['ruku'] as int,
        manzil: json['manzil'] as int,
        // The API sends `false` for ordinary ayahs, but an object like
        // {id, recommended, obligatory} for the 15 sajda ayahs.
        sajda: json['sajda'] != false,
        sajdaObligatory: json['sajda'] is Map
            ? (json['sajda'] as Map)['obligatory'] as bool?
            : null,
        textAr: json['text'] as String,
      );
}
