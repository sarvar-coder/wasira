import 'dart:convert';
import 'dart:io';

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

  group('every locale is complete', () {
    // Read as data rather than through AppLocalizations: a key missing from a
    // locale silently falls back to English at runtime, which is exactly the
    // failure this has to catch.
    Map<String, String> arb(String code) {
      final raw = jsonDecode(
          File('lib/l10n/app_$code.arb').readAsStringSync()) as Map<String, dynamic>;
      return {
        for (final entry in raw.entries)
          if (!entry.key.startsWith('@')) entry.key: entry.value as String,
      };
    }

    /// Names inside `{...}`, including those nested in an ICU plural body.
    Set<String> placeholders(String value) =>
        RegExp(r'\{(\w+)\}').allMatches(value).map((m) => m[1]!).toSet();

    /// The app is called Wasira in every language; it is a name, not a word to
    /// translate, so uz and ru keep it verbatim.
    const sameEverywhere = {'appTitle'};

    final english = arb('en');

    test('carries every key English has', () {
      for (final code in ['uz', 'ru', 'ar']) {
        final other = arb(code);
        for (final key in english.keys) {
          expect(other.containsKey(key), isTrue,
              reason: '$code is missing $key, which falls back to English '
                  'silently at runtime');
        }
      }
    });

    test('has nothing left in English', () {
      for (final code in ['uz', 'ru', 'ar']) {
        final other = arb(code);
        for (final key in english.keys) {
          if (sameEverywhere.contains(key)) continue;
          expect(other[key], isNot(english[key]),
              reason: '$code still shows the English text for $key');
        }
      }
    });

    test('keeps every placeholder, so no value loses its number', () {
      for (final code in ['uz', 'ru', 'ar']) {
        final other = arb(code);
        for (final key in english.keys) {
          expect(placeholders(other[key]!), placeholders(english[key]!),
              reason: '$code changed the placeholders of $key; a dropped one '
                  'renders the sentence without its number');
        }
      }
    });

    test('has no blank string standing in for a translation', () {
      for (final code in ['en', 'uz', 'ru', 'ar']) {
        arb(code).forEach((key, value) {
          expect(value.trim(), isNotEmpty, reason: '$code has an empty $key');
        });
      }
    });

    test('calls a bookmark one thing per locale', () {
      // The list said "saved" while the menu said "bookmark"; one concept
      // needs one word or the two screens read as two features.
      // Stems, not whole words: Russian inserts a vowel in the genitive
      // plural (закладок) and Arabic prefixes the article (المحفوظات).
      const stems = {
        'en': 'bookmark',
        'uz': "xatcho'p",
        'ru': 'заклад',
        'ar': 'محفوظات',
      };
      for (final code in stems.keys) {
        final other = arb(code);
        for (final key in ['navBookmarks', 'bookmark', 'removeBookmark', 'noBookmarks']) {
          expect(other[key]!.toLowerCase(), contains(stems[code]!),
              reason: '$code $key does not use the same word as the rest');
        }
      }
    });
  });

  group('Arabic plural rules', () {
    // CLDR gives Arabic six categories. Getting these wrong is the kind of
    // error that only shows up on a surah with the wrong number of ayahs.
    test('agree with the number, singular through plural', () async {
      final ar = await load('ar');

      expect(ar.ayahCount(1), 'آية واحدة');
      expect(ar.ayahCount(2), 'آيتان');
      // 3 to 10 take the plural noun.
      expect(ar.ayahCount(7), '7 آيات');
      // 11 upwards return to the singular. Al-Baqarah is 286.
      expect(ar.ayahCount(286), '286 آية');
    });

    test('one and two carry no digit, because Arabic does not use one', () async {
      final ar = await load('ar');
      expect(ar.ayahCount(1), isNot(contains('1')));
      expect(ar.ayahCount(2), isNot(contains('2')));
    });
  });
}
