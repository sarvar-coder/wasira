import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasira/l10n/app_localizations.dart';

/// The app ships four UI languages, and Arabic exists partly to force RTL
/// mirroring bugs out during development rather than after a user hits them.
void main() {
  Future<AppLocalizations> load(String code) =>
      AppLocalizations.delegate.load(Locale(code));

  test('all four locales are supported', () {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
      {'en', 'uz', 'ru', 'ar'},
    );
  });

  test('every locale translates the navigation labels', () async {
    for (final code in ['en', 'uz', 'ru', 'ar']) {
      final l10n = await load(code);
      for (final label in [
        l10n.navSurahs,
        l10n.navBookmarks,
        l10n.navDaily,
        l10n.navDownloads,
      ]) {
        expect(label, isNotEmpty, reason: 'missing a nav label in $code');
      }
    }
  });

  test('locales differ from English, so nothing silently fell back', () async {
    final en = await load('en');
    for (final code in ['uz', 'ru', 'ar']) {
      final other = await load(code);
      expect(other.navSurahs, isNot(en.navSurahs),
          reason: '$code navSurahs looks untranslated');
      expect(other.chooseTranslation, isNot(en.chooseTranslation),
          reason: '$code chooseTranslation looks untranslated');
    }
  });

  test('plurals are wired per locale', () async {
    expect((await load('en')).ayahCount(1), '1 ayah');
    expect((await load('en')).ayahCount(7), '7 ayahs');
    // Russian has three plural forms; a naive translation collapses them.
    final ru = await load('ru');
    expect(ru.ayahCount(1), isNot(ru.ayahCount(5)));
  });

  testWidgets('Arabic locale mirrors the layout to RTL', (tester) async {
    late TextDirection direction;

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        direction = Directionality.of(context);
        return const SizedBox();
      }),
    ));

    expect(direction, TextDirection.rtl);
  });

  testWidgets('English locale stays LTR', (tester) async {
    late TextDirection direction;

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        direction = Directionality.of(context);
        return const SizedBox();
      }),
    ));

    expect(direction, TextDirection.ltr);
  });
}
