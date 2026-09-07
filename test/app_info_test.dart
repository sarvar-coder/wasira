import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wasira/domain/app_info.dart';

void main() {
  test('the version shown in About is the version being built', () {
    // A hand-written constant drifts from pubspec silently, and the only place
    // anyone would notice is the About box — which nobody looks at.
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final line = pubspec.firstWhere((l) => l.startsWith('version:'));
    final version = line.split(':')[1].trim().split('+').first;

    expect(appVersion, version);
  });

  test('the font notice matches the font actually shipped', () {
    // The SIL Open Font License requires this notice to travel with the font.
    // Both files are in assets/fonts/ and both ship inside the bundle.
    expect(File('assets/fonts/AmiriQuran-Regular.ttf').existsSync(), isTrue);
    expect(File('assets/fonts/OFL.txt').existsSync(), isTrue);

    final licence = File('assets/fonts/OFL.txt').readAsStringSync();
    expect(licence, contains('SIL OPEN FONT LICENSE Version 1.1'));
    expect(licence, contains('The Amiri Project Authors'));
    expect(fontCopyright, contains('The Amiri Project Authors'));
  });

  test('the data source is credited by name and by address', () {
    expect(quranSource, isNotEmpty);
    expect(quranSourceUrl, startsWith('https://'));
  });
}
