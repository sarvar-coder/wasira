import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('ru'),
    Locale('uz'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Wasira'**
  String get appTitle;

  /// Heading of the first-launch language picker
  ///
  /// In en, this message translates to:
  /// **'Choose a translation'**
  String get chooseTranslation;

  /// No description provided for @pickerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{translations} translations in {languages} languages. You can change this later.'**
  String pickerSubtitle(int translations, int languages);

  /// No description provided for @translationsAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count} available'**
  String translationsAvailable(int count);

  /// No description provided for @serviceUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the Quran service'**
  String get serviceUnreachable;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @surahsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not load surahs'**
  String get surahsUnavailable;

  /// No description provided for @downloadingQuran.
  ///
  /// In en, this message translates to:
  /// **'Downloading the Quran'**
  String get downloadingQuran;

  /// No description provided for @notBuiltYet.
  ///
  /// In en, this message translates to:
  /// **'Not built yet'**
  String get notBuiltYet;

  /// No description provided for @navSurahs.
  ///
  /// In en, this message translates to:
  /// **'Surahs'**
  String get navSurahs;

  /// No description provided for @navBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get navBookmarks;

  /// No description provided for @navDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get navDaily;

  /// No description provided for @navDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get navDownloads;

  /// No description provided for @ayahCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 ayah} other{{count} ayahs}}'**
  String ayahCount(int count);

  /// No description provided for @revelationMeccan.
  ///
  /// In en, this message translates to:
  /// **'Meccan'**
  String get revelationMeccan;

  /// No description provided for @revelationMedinan.
  ///
  /// In en, this message translates to:
  /// **'Medinan'**
  String get revelationMedinan;

  /// Expands a translation clamped for length
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMore;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// Marker on an ayah of prostration
  ///
  /// In en, this message translates to:
  /// **'Prostration'**
  String get sajdaHere;

  /// No description provided for @sajdaObligatoryHere.
  ///
  /// In en, this message translates to:
  /// **'Obligatory prostration'**
  String get sajdaObligatoryHere;

  /// No description provided for @arabicTextSize.
  ///
  /// In en, this message translates to:
  /// **'Arabic text size'**
  String get arabicTextSize;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @nextAyah.
  ///
  /// In en, this message translates to:
  /// **'Next ayah'**
  String get nextAyah;

  /// No description provided for @previousAyah.
  ///
  /// In en, this message translates to:
  /// **'Previous ayah'**
  String get previousAyah;

  /// No description provided for @repeatOff.
  ///
  /// In en, this message translates to:
  /// **'No repeat'**
  String get repeatOff;

  /// No description provided for @repeatAyah.
  ///
  /// In en, this message translates to:
  /// **'Repeat ayah'**
  String get repeatAyah;

  /// No description provided for @repeatRange.
  ///
  /// In en, this message translates to:
  /// **'Repeat range'**
  String get repeatRange;

  /// No description provided for @reciter.
  ///
  /// In en, this message translates to:
  /// **'Reciter'**
  String get reciter;

  /// No description provided for @playbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Playback failed'**
  String get playbackFailed;

  /// No description provided for @wholeSurahReciter.
  ///
  /// In en, this message translates to:
  /// **'This reciter publishes whole surahs, so single ayahs cannot be addressed'**
  String get wholeSurahReciter;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @resumeDownload.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeDownload;

  /// No description provided for @deleteDownload.
  ///
  /// In en, this message translates to:
  /// **'Delete download'**
  String get deleteDownload;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailed;

  /// Total disk taken by one reciter's downloads
  ///
  /// In en, this message translates to:
  /// **'{size} on disk'**
  String storageUsed(String size);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'uz':
      return AppLocalizationsUz();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
