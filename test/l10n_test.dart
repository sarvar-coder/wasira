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

  test('every locale translates what the app actually shows', () async {
    for (final code in ['en', 'uz', 'ru', 'ar']) {
      final l10n = await load(code);
      for (final label in [
        l10n.chooseTranslation,
        l10n.dailySettings,
        l10n.reminders,
        l10n.arabicTextSize,
        l10n.serviceUnreachable,
        l10n.tryAgain,
        l10n.copyAyah,
      ]) {
        expect(label, isNotEmpty, reason: 'missing a label in $code');
      }
    }
  });

  test('locales differ from English, so nothing silently fell back', () async {
    final en = await load('en');
    for (final code in ['uz', 'ru', 'ar']) {
      final other = await load(code);
      expect(other.chooseTranslation, isNot(en.chooseTranslation),
          reason: '$code chooseTranslation looks untranslated');
      expect(other.dailySettings, isNot(en.dailySettings),
          reason: '$code dailySettings looks untranslated');
    }
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

    test('is called the same thing in every locale', () {
      // appTitle is exempt from the "nothing left in English" check below, so
      // without this the exemption would hide a divergence rather than record
      // a decision. Arabic used to read وسيلة — a different word.
      for (final code in ['uz', 'ru', 'ar']) {
        expect(arb(code)['appTitle'], english['appTitle'],
            reason: 'the app has one name, not one per language');
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
  });
}
