import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wasira/domain/bismillah.dart';

/// The highest-stakes test in the app. Every case runs against real captured
/// alquran.cloud text, not hand-written strings, because the whole point is
/// that the split matches what the API actually sends.
/// The malformed spelling in surahs 95 and 97 is one code unit longer than the
/// canonical one: it inserts a shadda on the beh.
final _bismillahWithShaddaLength = bismillahUthmani.length + 1;

void main() {
  final raw = jsonDecode(
      File('test/fixtures/ayah_ones_uthmani.json').readAsStringSync()) as Map;

  String ayahOne(int surah) => raw['$surah'] as String;

  BismillahSplit split(int surah, {int numberInSurah = 1, String? text}) =>
      splitOpeningBismillah(
        surah: surah,
        numberInSurah: numberInSurah,
        text: text ?? ayahOne(surah),
      );

  test('the constant matches what the API actually sends', () {
    // Surah 1 ayah 1 IS the Bismillah, so it doubles as the reference string.
    // If the API changes its orthography this fails rather than silently
    // disabling every split.
    expect(ayahOne(1).replaceFirst('﻿', ''), bismillahUthmani);
  });

  group('Al-Fatiha keeps its Bismillah as ayah 1', () {
    test('no header is produced', () {
      expect(split(1).header, isNull);
    });

    test('the ayah keeps its full text and loses only the BOM', () {
      expect(split(1).text, bismillahUthmani);
      expect(split(1).text, isNotEmpty,
          reason: 'stripping here would empty Al-Fatiha 1:1');
    });
  });

  group('At-Tawbah has no Bismillah at all', () {
    test('no header is produced', () {
      expect(split(9).header, isNull);
    });

    test('its opening words survive untouched', () {
      // Compared against the fixture rather than a typed literal: hand-typing
      // Arabic here already produced a false failure once.
      expect(split(9).text, ayahOne(9));
      expect(split(9).text, isNot(contains(bismillahUthmani)));
    });
  });

  group('every other surah splits', () {
    test('all 112 produce a header and a non-empty remainder', () {
      final failures = <String>[];
      for (var s = 1; s <= 114; s++) {
        if (s == 1 || s == 9) continue;
        final result = split(s);
        if (result.header != bismillahUthmani) {
          failures.add('surah $s: no header');
        }
        if (result.text.trim().isEmpty) {
          failures.add('surah $s: empty remainder');
        }
        if (result.text.contains(bismillahUthmani)) {
          failures.add('surah $s: Bismillah still in ayah text');
        }
      }
      expect(failures, isEmpty);
    });

    test('Al-Baqarah 2:1 becomes الٓمٓ alone', () {
      expect(split(2).text, 'الٓمٓ');
    });

    test('An-Naml 27:1 becomes طسٓ and keeps the rest of its ayah', () {
      expect(split(27).text, startsWith('طسٓ'));
      expect(split(27).text, isNot(contains(bismillahUthmani)));
    });
  });

  group('27:30 is never touched', () {
    final text = raw['27:30'] as String;

    test('its Bismillah sits mid-ayah, inside Sulayman letter', () {
      expect(text, contains(bismillahUthmani));
      expect(text.startsWith(bismillahUthmani), isFalse);
    });

    test('splitting returns it byte-identical', () {
      final result = split(27, numberInSurah: 30, text: text);

      expect(result.text, text);
      expect(result.header, isNull);
    });
  });

  group('safety', () {
    test('ayahs other than the first are returned unchanged', () {
      const text = 'أي نص';
      expect(split(2, numberInSurah: 2, text: text).text, text);
      expect(split(2, numberInSurah: 2, text: text).header, isNull);
    });

    test('an unrecognised orthography is left whole rather than mangled', () {
      // quran-simple uses plain alef (U+0627) where uthmani uses alef wasla
      // (U+0671), so its prefix does not match this constant.
      const simple = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ الم';

      final result = split(2, text: simple);

      expect(result.text, simple, reason: 'must not partially strip');
      expect(result.header, isNull);
    });

    test('a caller can supply the prefix for another edition', () {
      const simpleBismillah = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';
      const simple = '$simpleBismillah الم';

      final result = splitOpeningBismillah(
        surah: 2,
        numberInSurah: 1,
        text: simple,
        bismillah: simpleBismillah,
      );

      expect(result.header, simpleBismillah);
      expect(result.text, 'الم');
    });
  });

  group('the two surahs the API sends malformed', () {
    // At-Tin and Al-Qadr arrive with a spurious U+0651 SHADDA on the beh.
    for (final surah in [95, 97]) {
      test('surah $surah carries the malformed spelling upstream', () {
        expect(ayahOne(surah).startsWith(bismillahUthmani), isFalse);
        expect(ayahOne(surah).codeUnits[1], 0x0651,
            reason: 'expected the spurious shadda this case exists for');
      });

      test('surah $surah still splits, with the canonical header', () {
        final result = split(surah);

        expect(result.header, bismillahUthmani);
        expect(result.text.trim(), isNotEmpty);
        expect(result.text, isNot(contains('بِّسْمِ')));
      });
    }

    test('the malformed prefix is fully removed, not partially', () {
      // Derived from the fixture rather than typed: hand-typing Arabic into an
      // assertion has produced two false failures in this file already.
      for (final surah in [95, 97]) {
        final raw = ayahOne(surah);
        final expected = raw.substring(_bismillahWithShaddaLength).trimLeft();

        expect(split(surah).text, expected);
        expect(split(surah).text.length, lessThan(raw.length));
      }
    });
  });
}
