// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Wasira';

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
  String get serviceUnreachable => 'تعذر الوصول إلى خدمة القرآن الكريم';

  @override
  String get tryAgain => 'أعد المحاولة';

  @override
  String get showMore => 'عرض المزيد';

  @override
  String get sajdaHere => 'سجدة تلاوة';

  @override
  String get sajdaObligatoryHere => 'سجدة تلاوة واجبة';

  @override
  String get arabicTextSize => 'حجم النص العربي';

  @override
  String get dailySettings => 'إعدادات آية اليوم';

  @override
  String get reminders => 'التذكيرات';

  @override
  String get copyAyah => 'نسخ';

  @override
  String get copied => 'تم النسخ';
}
