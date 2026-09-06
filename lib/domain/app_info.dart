/// What the app says about itself, and who it owes.
library;

/// Mirrors `version:` in pubspec.yaml. `app_info_test.dart` fails if the two
/// drift, which is the only thing keeping a hand-written constant honest.
const appVersion = '1.0.0';

/// The Quran text and every translation come from one free, keyless API run by
/// the Islamic Network. Naming it is the least the app can do.
const quranSource = 'alquran.cloud';
const quranSourceUrl = 'https://alquran.cloud';

/// Amiri Quran ships inside the app, and the SIL Open Font License requires its
/// copyright notice and licence to travel with it. This is that notice; the
/// full licence is `assets/fonts/OFL.txt`, which ships in the bundle.
///
/// Read out of the font's own name table rather than copied from a web page,
/// so it cannot drift from the file actually being redistributed.
const fontName = 'Amiri Quran';
const fontCopyright =
    'Copyright 2010-2022 The Amiri Project Authors '
    '(https://github.com/aliftype/amiri).';
const fontLicence = 'SIL Open Font License, Version 1.1';
const fontLicenceUrl = 'https://openfontlicense.org';
