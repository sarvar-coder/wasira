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
  String get surahsUnavailable => 'Не удалось загрузить суры';

  @override
  String get downloadingQuran => 'Загрузка Корана';

  @override
  String get notBuiltYet => 'Ещё не готово';

  @override
  String get navSurahs => 'Суры';

  @override
  String get navBookmarks => 'Закладки';

  @override
  String get navDaily => 'Ежедневно';

  @override
  String get navDownloads => 'Загрузки';

  @override
  String ayahCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count аятов',
      few: '$count аята',
      one: '$count аят',
    );
    return '$_temp0';
  }

  @override
  String get revelationMeccan => 'Мекканская';

  @override
  String get revelationMedinan => 'Мединская';

  @override
  String get showMore => 'Показать полностью';

  @override
  String get showLess => 'Свернуть';

  @override
  String get sajdaHere => 'Земной поклон';

  @override
  String get sajdaObligatoryHere => 'Обязательный земной поклон';

  @override
  String get arabicTextSize => 'Размер арабского текста';

  @override
  String get play => 'Воспроизвести';

  @override
  String get pause => 'Пауза';

  @override
  String get nextAyah => 'Следующий аят';

  @override
  String get previousAyah => 'Предыдущий аят';

  @override
  String get repeatOff => 'Без повтора';

  @override
  String get repeatAyah => 'Повтор аята';

  @override
  String get repeatRange => 'Повтор отрывка';

  @override
  String get reciter => 'Чтец';

  @override
  String get playbackFailed => 'Не удалось воспроизвести';

  @override
  String get wholeSurahReciter =>
      'Этот чтец записан сурами целиком, поэтому отдельные аяты недоступны';

  @override
  String get download => 'Скачать';

  @override
  String get resumeDownload => 'Продолжить';

  @override
  String get deleteDownload => 'Удалить загрузку';

  @override
  String get downloadFailed => 'Не удалось скачать';

  @override
  String storageUsed(String size) {
    return '$size на диске';
  }
}
