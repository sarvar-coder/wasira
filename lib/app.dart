import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data/repositories/quran_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'l10n/app_localizations.dart';
import 'data/services/audio_download_service.dart';
import 'data/services/database_service.dart';
import 'data/services/notification_service.dart';
import 'ui/core/themes/tokens.dart';
import 'ui/bookmarks/bookmarks_bloc.dart';
import 'ui/bookmarks/bookmarks_event.dart';
import 'ui/bookmarks/widgets/bookmarks_screen.dart';
import 'ui/core/ui/app_shell.dart';
import 'data/repositories/bookmark_repository.dart';
import 'data/repositories/daily_repository.dart';
import 'ui/daily/daily_bloc.dart';
import 'ui/daily/daily_event.dart';
import 'ui/daily/widgets/daily_screen.dart';
import 'ui/downloads/downloads_bloc.dart';
import 'ui/downloads/downloads_event.dart';
import 'ui/downloads/widgets/downloads_screen.dart';
import 'ui/onboarding/onboarding_bloc.dart';
import 'ui/onboarding/onboarding_event.dart';
import 'ui/onboarding/onboarding_state.dart';
import 'ui/onboarding/widgets/onboarding_screen.dart';
import 'ui/surah_list/surah_list_bloc.dart';
import 'ui/surah_list/surah_list_event.dart';
import 'ui/surah_list/widgets/surah_list_screen.dart';

class WasiraApp extends StatelessWidget {
  const WasiraApp({
    super.key,
    required this.repository,
    required this.db,
    required this.downloads,
    this.notifications,
  });

  final QuranRepository repository;
  final DatabaseService db;

  /// Read deep in the reader, so it is provided rather than threaded through
  /// every widget between here and the audio bar.
  final AudioDownloadService downloads;

  /// Null in tests. The daily screen reschedules through it when the count or
  /// a reminder time changes.
  final NotificationService? notifications;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [
          RepositoryProvider.value(value: downloads),
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
              repository: app.repository,
              settings: SettingsRepository(app.db),
              translationEdition: edition,
              bookmarks: BookmarkRepository(app.db)),
        ),
        ShellDestination(
          l10n.navBookmarks,
          Icons.star_outline,
          (_) => BlocProvider(
            // Rebuilt when the tab is entered, which is also how it picks up
            // ayahs saved from the reader since it was last open.
            create: (_) => BookmarksBloc(
              repository: app.repository,
              bookmarks: BookmarkRepository(app.db),
              translationEdition: edition,
            )..add(BookmarksRequested()),
            child: BookmarksScreen(
              repository: app.repository,
              settings: SettingsRepository(app.db),
              bookmarks: BookmarkRepository(app.db),
              translationEdition: edition,
            ),
          ),
        ),
        ShellDestination(
          l10n.navDaily,
          Icons.wb_sunny_outlined,
          (_) => BlocProvider(
            create: (_) => DailyBloc(
              repository: app.repository,
              daily: DailyRepository(
                db: app.db,
                settings: SettingsRepository(app.db),
              ),
              settings: SettingsRepository(app.db),
              translationEdition: edition,
              notifications: app.notifications,
            )..add(DailyRequested()),
            child: const DailyScreen(),
          ),
        ),
        ShellDestination(
          l10n.navDownloads,
          Icons.download_outlined,
          // Its own bloc rather than an app-wide one: a download queued here
          // keeps running through [DownloadsBloc]'s own future chain, and the
          // screen re-scans disk when it comes back.
          (_) => BlocProvider(
            create: (_) => DownloadsBloc(
              repository: app.repository,
              downloads: app.downloads,
              settings: SettingsRepository(app.db),
            )..add(DownloadsRequested()),
            child: const DownloadsScreen(),
          ),
        ),
      ],
    );
  }
}

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
