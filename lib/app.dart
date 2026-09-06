import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data/repositories/quran_repository.dart';
import 'l10n/app_localizations.dart';
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
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          // Arabic is shipped deliberately: it exercises RTL mirroring during
          // development instead of after an Arabic user reports it.
          supportedLocales: AppLocalizations.supportedLocales,
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
          OnboardingSyncing(:final edition, :final progress) =>
            _Shell(edition: edition, progress: progress),
          OnboardingReady(:final edition) => _Shell(edition: edition),
        },
      );
}

class _Shell extends StatelessWidget {
  const _Shell({required this.edition, this.progress});

  /// The translation the user chose. Ayah text is shown alongside it.
  final String edition;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final app = context.findAncestorWidgetOfExactType<WasiraApp>()!;

    return AppShell(
      banner: progress == null ? null : _SyncBanner(progress: progress!),
      destinations: [
        ShellDestination(
          l10n.navSurahs,
          Icons.menu_book_outlined,
          (_) => SurahListScreen(
              repository: app.repository, translationEdition: edition),
        ),
        ShellDestination(l10n.navBookmarks, Icons.star_outline, _buildTodo),
        ShellDestination(l10n.navDaily, Icons.wb_sunny_outlined, _buildTodo),
        ShellDestination(l10n.navDownloads, Icons.download_outlined, _buildTodo),
      ],
    );
  }
}

Widget _buildTodo(BuildContext context) => Center(
      child: Text(AppLocalizations.of(context)!.notBuiltYet,
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
              Text(AppLocalizations.of(context)!.downloadingQuran,
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
