// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Wasira';

  @override
  String get chooseTranslation => 'Выберите перевод';

  @override
  String pickerSubtitle(int translations, int languages) {
    return '$translations переводов на $languages языках. Это можно изменить позже.';
  }

  @override
  String translationsAvailable(int count) {
    return 'доступно: $count';
  }

  @override
  String get serviceUnreachable => 'Не удалось связаться со службой Корана';

  @override
  String get tryAgain => 'Повторить';

  @override
  String get showMore => 'Показать полностью';

  @override
  String get sajdaHere => 'Земной поклон';

  @override
  String get sajdaObligatoryHere => 'Обязательный земной поклон';

  @override
  String get arabicTextSize => 'Размер арабского текста';

  @override
  String get dailySettings => 'Настройки дня';

  @override
  String get reminders => 'Напоминания';

  @override
  String get copyAyah => 'Копировать';

  @override
  String get copied => 'Скопировано';
}
