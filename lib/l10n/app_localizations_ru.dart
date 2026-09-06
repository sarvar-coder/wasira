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
}
