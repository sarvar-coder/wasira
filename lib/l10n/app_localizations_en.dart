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
  String get surahsUnavailable => 'Could not load surahs';

  @override
  String get downloadingQuran => 'Downloading the Quran';

  @override
  String get notBuiltYet => 'Not built yet';

  @override
  String get navSurahs => 'Surahs';

  @override
  String get navBookmarks => 'Bookmarks';

  @override
  String get navDaily => 'Daily';

  @override
  String get navDownloads => 'Downloads';

  @override
  String ayahCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ayahs',
      one: '1 ayah',
    );
    return '$_temp0';
  }

  @override
  String get revelationMeccan => 'Meccan';

  @override
  String get revelationMedinan => 'Medinan';

  @override
  String get showMore => 'Show more';

  @override
  String get showLess => 'Show less';

  @override
  String get sajdaHere => 'Prostration';

  @override
  String get sajdaObligatoryHere => 'Obligatory prostration';

  @override
  String get arabicTextSize => 'Arabic text size';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get nextAyah => 'Next ayah';

  @override
  String get previousAyah => 'Previous ayah';

  @override
  String get repeatOff => 'No repeat';

  @override
  String get repeatAyah => 'Repeat ayah';

  @override
  String get repeatRange => 'Repeat range';

  @override
  String get reciter => 'Reciter';

  @override
  String get playbackFailed => 'Playback failed';

  @override
  String get wholeSurahReciter =>
      'This reciter publishes whole surahs, so single ayahs cannot be addressed';

  @override
  String get download => 'Download';

  @override
  String get resumeDownload => 'Resume';

  @override
  String get deleteDownload => 'Delete download';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String storageUsed(String size) {
    return '$size on disk';
  }

  @override
  String get today => 'Today';

  @override
  String get pickADay => 'Pick a day';

  @override
  String get dailySettings => 'Daily settings';

  @override
  String get ayahsPerDay => 'Ayahs a day';

  @override
  String get reminders => 'Reminders';

  @override
  String get noFutureDays => 'A day that has not arrived has no ayahs yet';
}
