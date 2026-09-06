// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'وسيلة';

  @override
  String get chooseTranslation => 'اختر ترجمة';

  @override
  String pickerSubtitle(int translations, int languages) {
    return '$translations ترجمة بـ $languages لغة. يمكنك تغيير ذلك لاحقًا.';
  }

  @override
  String translationsAvailable(int count) {
    return '$count متاحة';
  }

  @override
  String get serviceUnreachable => 'تعذر الوصول إلى خدمة القرآن';

  @override
  String get tryAgain => 'أعد المحاولة';

  @override
  String get surahsUnavailable => 'تعذر تحميل السور';

  @override
  String get downloadingQuran => 'جارٍ تحميل القرآن';

  @override
  String get notBuiltYet => 'غير جاهز بعد';

  @override
  String get navSurahs => 'السور';

  @override
  String get navBookmarks => 'المحفوظات';

  @override
  String get navDaily => 'اليومي';

  @override
  String get navDownloads => 'التنزيلات';

  @override
  String ayahCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count آية',
      few: '$count آيات',
      two: 'آيتان',
      one: 'آية واحدة',
    );
    return '$_temp0';
  }

  @override
  String get revelationMeccan => 'مكية';

  @override
  String get revelationMedinan => 'مدنية';

  @override
  String get showMore => 'عرض المزيد';

  @override
  String get showLess => 'عرض أقل';

  @override
  String get sajdaHere => 'سجدة';

  @override
  String get sajdaObligatoryHere => 'سجدة واجبة';

  @override
  String get arabicTextSize => 'حجم النص العربي';
}
