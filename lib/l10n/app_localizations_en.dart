// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Wasira';

  @override
  String get chooseTranslation => 'Choose a translation';

  @override
  String pickerSubtitle(int translations, int languages) {
    return '$translations translations in $languages languages. You can change this later.';
  }

  @override
  String translationsAvailable(int count) {
    return '$count available';
  }

  @override
  String get serviceUnreachable => 'Could not reach the Quran service';

  @override
  String get tryAgain => 'Try again';

  @override
  String get showMore => 'Show more';

  @override
  String get sajdaHere => 'Prostration';

  @override
  String get sajdaObligatoryHere => 'Obligatory prostration';

  @override
  String get arabicTextSize => 'Arabic text size';

  @override
  String get dailySettings => 'Daily settings';

  @override
  String get reminders => 'Reminders';

  @override
  String get copyAyah => 'Copy';

  @override
  String get copied => 'Copied';
}
