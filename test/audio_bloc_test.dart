import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wasira/data/repositories/settings_repository.dart';
import 'package:wasira/data/services/audio_download_service.dart';
import 'package:wasira/data/services/audio_player_service.dart';
import 'package:wasira/data/services/database_service.dart';
import 'package:wasira/domain/reciter.dart';
import 'package:wasira/ui/reader/audio_bloc.dart';
import 'package:wasira/ui/reader/audio_event.dart';

/// Records what the bloc asked the player to do, so behaviour can be asserted
/// without a real audio device.
class _SpyPlayer implements AudioPlayerService {
  final calls = <String>[];
  final _ayahs = StreamController<int?>.broadcast();

  Reciter? loadedReciter;
  List<int> loadedQueue = const [];
  int? loadedStartAt;

  void emitAyah(int? n) => _ayahs.add(n);

  /// Streaming, not offline: source resolution is the download service's own
  /// test.
  @override
  AudioDownloadService? get downloads => null;

  @override
  Stream<int?> get currentAyah => _ayahs.stream;

  @override
  Future<void> load({
    required Reciter reciter,
    required int surah,
    required List<int> ayahNumbers,
    int startAt = 0,
  }) async {
    calls.add('load');
    loadedReciter = reciter;
    loadedQueue = ayahNumbers;
    loadedStartAt = startAt;
  }

  @override
  Future<void> play() async => calls.add('play');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> nextAyah() async => calls.add('next');
  @override
  Future<void> previousAyah() async => calls.add('previous');
  @override
  Future<void> setRepeat(RecitationRepeat mode) async =>
      calls.add('repeat:${mode.name}');
  @override
  Future<void> dispose() async => _ayahs.close();

  @override
  Stream<bool> get playing => const Stream.empty();
  @override
  Stream<Duration> get position => const Stream.empty();
}

void main() {
  late Database db;
  late SettingsRepository settings;
  late _SpyPlayer player;

  // Al-Fatiha: global ayah numbers 1..7.
  const alFatiha = [1, 2, 3, 4, 5, 6, 7];

  setUp(() {
    db = sqlite3.openInMemory();
    settings = SettingsRepository(DatabaseService(db)..migrate());
    player = _SpyPlayer();
  });
  tearDown(() => db.close());

  AudioBloc makeBloc() => AudioBloc(
        player: player,
        settings: settings,
        surah: 1,
        ayahNumbers: alFatiha,
      );

  test('opens with the stored reciter', () async {
    settings.setReciter(Reciter.husaryMujawwad);

    final bloc = makeBloc();
    addTearDown(bloc.close);

    expect(bloc.state.reciter, Reciter.husaryMujawwad);
  });

  test('playing loads the surah queue then plays', () async {
    final bloc = makeBloc()..add(PlaybackRequested());
    addTearDown(bloc.close);
    // The handler emits once to clear any error before it loads, so waiting on
    // the first emit would assert before the work happened.
    await bloc.stream.firstWhere((s) => s.playing);

    expect(player.calls, containsAllInOrder(['load', 'play']));
    expect(player.loadedQueue, alFatiha);
  });

  test('playing from an ayah starts at its index, not its number', () async {
    final bloc = makeBloc()..add(PlaybackRequested(fromAyah: 5));
    addTearDown(bloc.close);
    await bloc.stream.firstWhere((s) => s.playing);

    expect(player.loadedStartAt, 4, reason: 'ayah 5 is index 4');
  });

  test('a second play does not reload the queue', () async {
    final bloc = makeBloc()..add(PlaybackRequested());
    addTearDown(bloc.close);
    await bloc.stream.firstWhere((s) => s.playing);
    bloc.add(PlaybackPaused());
    await bloc.stream.firstWhere((s) => !s.playing);

    bloc.add(PlaybackRequested());
    await bloc.stream.firstWhere((s) => s.playing);

    expect(player.calls.where((c) => c == 'load'), hasLength(1));
  });

  test('the sounding ayah reaches the state', () async {
    final bloc = makeBloc();
    addTearDown(bloc.close);

    player.emitAyah(3);
    final state = await bloc.stream.first;

    expect(state.currentAyah, 3);
  });

  group('al-Luhaidan publishes whole surahs', () {
    test('ayah controls do not apply', () async {
      settings.setReciter(Reciter.luhaidan);

      final bloc = makeBloc();
      addTearDown(bloc.close);

      expect(bloc.state.ayahControlsApply, isFalse);
    });

    test('but a verse-by-verse reciter keeps them', () async {
      settings.setReciter(Reciter.alafasy);

      final bloc = makeBloc();
      addTearDown(bloc.close);

      expect(bloc.state.ayahControlsApply, isTrue);
    });
  });

  group('switching reciter', () {
    test('persists the choice and clears the sounding ayah', () async {
      final bloc = makeBloc();
      addTearDown(bloc.close);
      player.emitAyah(3);
      await bloc.stream.first;

      bloc.add(ReciterChanged(Reciter.luhaidan));
      final state = await bloc.stream.firstWhere(
          (s) => s.reciter.edition == Reciter.luhaidan.edition);

      expect(state.currentAyah, isNull,
          reason: 'the old ayah must not linger under a reciter that has none');
      expect(settings.reciter, Reciter.luhaidan);
    });

    test('rebuilds the queue rather than swapping it, since the path differs',
        () async {
      final bloc = makeBloc()..add(PlaybackRequested());
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((s) => s.playing);
      player.calls.clear();

      bloc.add(ReciterChanged(Reciter.luhaidan));
      // Changing reciter while playing resumes on its own, so the reload is
      // already in flight; wait for it to come back to playing.
      await bloc.stream.firstWhere(
          (s) => s.reciter.edition == Reciter.luhaidan.edition && s.playing);

      expect(player.calls, contains('load'));
      expect(player.loadedReciter, Reciter.luhaidan);
    });
  });

  test('repeat mode reaches the player', () async {
    final bloc = makeBloc();
    addTearDown(bloc.close);

    bloc.add(RecitationRepeatChanged(RecitationRepeat.ayah));
    await bloc.stream.first;

    expect(player.calls, contains('repeat:ayah'));
  });
}
