// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get appTitle => 'Wasira';

  @override
  String get chooseTranslation => 'Tarjimani tanlang';

  @override
  String pickerSubtitle(int translations, int languages) {
    return '$languages tilda $translations ta tarjima. Buni keyin ham o\'zgartirishingiz mumkin.';
  }

  @override
  String translationsAvailable(int count) {
    return '$count ta mavjud';
  }

  @override
  String get serviceUnreachable => 'Qur\'on xizmatiga ulanib bo\'lmadi';

  @override
  String get tryAgain => 'Qayta urinish';

  @override
  String get surahsUnavailable => 'Suralarni yuklab bo\'lmadi';

  @override
  String get downloadingQuran => 'Qur\'on yuklanmoqda';

  @override
  String get notBuiltYet => 'Hali tayyor emas';

  @override
  String get navSurahs => 'Suralar';

  @override
  String get navBookmarks => 'Xatcho\'plar';

  @override
  String get navDaily => 'Kunlik';

  @override
  String get navDownloads => 'Yuklamalar';

  @override
  String ayahCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oyat',
    );
    return '$_temp0';
  }

  @override
  String get revelationMeccan => 'Makkiy';

  @override
  String get revelationMedinan => 'Madaniy';

  @override
  String get showMore => 'Ko\'proq';

  @override
  String get showLess => 'Kamroq';

  @override
  String get sajdaHere => 'Sajda';

  @override
  String get sajdaObligatoryHere => 'Vojib sajda';

  @override
  String get arabicTextSize => 'Arab matni o\'lchami';

  @override
  String get play => 'Ijro';

  @override
  String get pause => 'To\'xtatish';

  @override
  String get nextAyah => 'Keyingi oyat';

  @override
  String get previousAyah => 'Oldingi oyat';

  @override
  String get repeatOff => 'Takrorlanmasin';

  @override
  String get repeatAyah => 'Oyatni takrorlash';

  @override
  String get repeatRange => 'Oraliqni takrorlash';

  @override
  String get reciter => 'Qori';

  @override
  String get playbackFailed => 'Ijro etilmadi';

  @override
  String get wholeSurahReciter =>
      'Bu qori butun surani o\'qigan, shuning uchun alohida oyatga o\'tib bo\'lmaydi';
}
