import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data/repositories/daily_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/alquran_api_service.dart';
import 'data/services/local_store.dart';
import 'data/services/notification_service.dart';
import 'l10n/app_localizations.dart';
import 'ui/core/themes/tokens.dart';
import 'ui/daily/daily_bloc.dart';
import 'ui/daily/daily_event.dart';
import 'ui/daily/widgets/daily_screen.dart';
import 'ui/onboarding/onboarding_bloc.dart';
import 'ui/onboarding/onboarding_event.dart';
import 'ui/onboarding/onboarding_state.dart';
import 'ui/onboarding/widgets/onboarding_screen.dart';

/// One ayah a day, in one window. There is no navigation, because there is
/// nowhere else to go.
class WasiraApp extends StatelessWidget {
  const WasiraApp({
    super.key,
    required this.api,
    required this.settingsStore,
    required this.dailyStore,
    this.notifications,
  });

  final AlquranApiService api;

  /// Two files rather than one: preferences outlive the day's ayah, and the
  /// ayah is deleted wholesale at every rollover.
  final LocalStore settingsStore;
  final LocalStore dailyStore;

  /// Null in tests. The settings sheet reschedules through it when a reminder
  /// time changes.
  final NotificationService? notifications;

  SettingsRepository get settings => SettingsRepository(settingsStore);

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) =>
            OnboardingBloc(api: api, settings: settings)..add(EditionsRequested()),
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
          OnboardingLoading() ||
          OnboardingFailed() ||
          OnboardingChoosing() =>
            const Scaffold(body: OnboardingScreen()),
          OnboardingReady(:final edition) => _Daily(edition: edition),
        },
      );
}

class _Daily extends StatelessWidget {
  const _Daily({required this.edition});

  /// The translation the user chose. The ayah is shown alongside it.
  final String edition;

  @override
  Widget build(BuildContext context) {
    final app = context.findAncestorWidgetOfExactType<WasiraApp>()!;

    return BlocProvider(
      create: (_) => DailyBloc(
        daily: DailyRepository(store: app.dailyStore, api: app.api),
        settings: app.settings,
        translationEdition: edition,
        notifications: app.notifications,
      )..add(DailyRequested()),
      child: const Scaffold(body: DailyScreen()),
    );
  }
}
