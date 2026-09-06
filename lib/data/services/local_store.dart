import 'dart:convert';
import 'dart:io';

/// A JSON file on disk.
///
/// This app stores three things: the chosen translation, five reminder times,
/// and today's ayah. SQLite carried a schema, eight tables and a migration
/// path for that; a file and `dart:convert` carry it in a few lines.
///
/// Reads never throw. A missing file is the first launch, and a corrupt one is
/// indistinguishable from it as far as the app can act — both mean "no value
/// yet", and a daily ayah is cheap to fetch again.
class LocalStore {
  LocalStore(this.file);

  final File file;

  Map<String, dynamic> read() {
    try {
      final text = file.readAsStringSync();
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  /// Written through a temporary file and renamed, so a crash mid-write leaves
  /// the previous contents rather than half of the new ones.
  void write(Map<String, dynamic> values) {
    final part = File('${file.path}.part');
    part.parent.createSync(recursive: true);
    part.writeAsStringSync(jsonEncode(values), flush: true);
    part.renameSync(file.path);
  }

  void update(Map<String, dynamic> changes) => write({...read(), ...changes});

  void clear() {
    if (file.existsSync()) file.deleteSync();
  }
}
