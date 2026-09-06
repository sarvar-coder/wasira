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
  String get navSurahs => 'السور';

  @override
  String get navBookmarks => 'المحفوظات';

  @override
  String get navDaily => 'آية اليوم';

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

  @override
  String get play => 'تشغيل';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get nextAyah => 'الآية التالية';

  @override
  String get previousAyah => 'الآية السابقة';

  @override
  String get repeatOff => 'بدون تكرار';

  @override
  String get repeatAyah => 'تكرار الآية';

  @override
  String get repeatRange => 'تكرار المقطع';

  @override
  String get reciter => 'القارئ';

  @override
  String get playbackFailed => 'تعذر التشغيل';

  @override
  String get wholeSurahReciter =>
      'هذا القارئ مسجَّل بالسور كاملة، لذا لا يمكن الانتقال إلى آية بعينها';

  @override
  String get download => 'تنزيل';

  @override
  String get resumeDownload => 'متابعة';

  @override
  String get deleteDownload => 'حذف التنزيل';

  @override
  String get downloadFailed => 'فشل التنزيل';

  @override
  String storageUsed(String size) {
    return '$size على القرص';
  }

  @override
  String get today => 'اليوم';

  @override
  String get pickADay => 'اختر يومًا';

  @override
  String get dailySettings => 'إعدادات آية اليوم';

  @override
  String get ayahsPerDay => 'آيات في اليوم';

  @override
  String get reminders => 'التذكيرات';

  @override
  String get noFutureDays => 'لا آيات ليومٍ لم يأتِ بعد';

  @override
  String get bookmark => 'إضافة إلى المحفوظات';

  @override
  String get removeBookmark => 'إزالة من المحفوظات';

  @override
  String get playFromHere => 'التشغيل من هنا';

  @override
  String get copyAyah => 'نسخ';

  @override
  String get shareAyah => 'مشاركة';

  @override
  String get copied => 'تم النسخ';

  @override
  String get noBookmarks => 'لا توجد محفوظات بعد';

  @override
  String get bookmarksHint =>
      'انقر على الآية بالزر الأيمن لإضافتها إلى المحفوظات';
}
