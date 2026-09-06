import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data/repositories/quran_repository.dart';
import 'data/services/database_service.dart';
import 'ui/core/themes/tokens.dart';
import 'ui/core/ui/app_shell.dart';
import 'ui/onboarding/onboarding_bloc.dart';
import 'ui/onboarding/onboarding_event.dart';
import 'ui/onboarding/onboarding_state.dart';
import 'ui/onboarding/widgets/onboarding_screen.dart';
import 'ui/surah_list/surah_list_bloc.dart';
import 'ui/surah_list/surah_list_event.dart';
import 'ui/surah_list/widgets/surah_list_screen.dart';

class WasiraApp extends StatelessWidget {
  const WasiraApp({super.key, required this.repository, required this.db});

  final QuranRepository repository;
  final DatabaseService db;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                OnboardingBloc(repository: repository, db: db)
                  ..add(EditionsRequested()),
          ),
          BlocProvider(
            create: (_) => SurahListBloc(repository)..add(SurahListRequested()),
          ),
        ],
        child: MaterialApp(
          title: 'Wasira',
          theme: Tokens.light.theme,
          darkTheme: Tokens.dark.theme,
          // No manual toggle: the app follows the system appearance.
          themeMode: ThemeMode.system,
          home: const _Root(),
        ),
      );
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<OnboardingBloc, OnboardingState>(
        builder: (context, state) => switch (state) {
          // Only the picker itself is a full-screen step. As soon as a language
          // is chosen the shell takes over and the download continues behind it.
          OnboardingLoading() ||
          OnboardingFailed() ||
          OnboardingChoosing() =>
            const Scaffold(body: OnboardingScreen()),
          OnboardingSyncing(:final progress) => _Shell(progress: progress),
          OnboardingReady() => const _Shell(),
        },
      );
}

class _Shell extends StatelessWidget {
  const _Shell({this.progress});
  final double? progress;

  @override
  Widget build(BuildContext context) => AppShell(
        banner: progress == null ? null : _SyncBanner(progress: progress!),
        destinations: const [
          ShellDestination('Surahs', Icons.menu_book_outlined,
              _buildSurahs),
          ShellDestination('Bookmarks', Icons.star_outline, _buildTodo),
          ShellDestination('Daily', Icons.wb_sunny_outlined, _buildTodo),
          ShellDestination('Downloads', Icons.download_outlined, _buildTodo),
        ],
      );
}

Widget _buildSurahs(BuildContext context) => const SurahListScreen();

Widget _buildTodo(BuildContext context) => Center(
      child: Text('Not built yet',
          style: TextStyle(color: Tokens.of(context).muted)),
    );

/// A thin strip, never a modal. The surah list behind it stays scrollable.
class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final tokens = Tokens.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Text('Downloading the Quran',
                  style: TextStyle(fontSize: 12, color: tokens.muted)),
              const Spacer(),
              Text('${(progress * 100).round()}%',
                  style: TextStyle(fontSize: 12, color: tokens.muted)),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: progress,
          minHeight: 2,
          backgroundColor: tokens.divider,
        ),
      ],
    );
  }
}
