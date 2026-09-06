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
  String get showMore => 'Ko\'proq';

  @override
  String get sajdaHere => 'Sajda';

  @override
  String get sajdaObligatoryHere => 'Vojib sajda';

  @override
  String get arabicTextSize => 'Arab matni o\'lchami';

  @override
  String get dailySettings => 'Kunlik sozlamalar';

  @override
  String get reminders => 'Eslatmalar';

  @override
  String get copyAyah => 'Nusxa olish';

  @override
  String get copied => 'Nusxa olindi';

  @override
  String get about => 'Ilova haqida';

  @override
  String get translation => 'Tarjima';

  @override
  String get version => 'Versiya';

  @override
  String textFrom(String source) {
    return 'Qur\'on matni va tarjimalari $source xizmatidan';
  }
}
