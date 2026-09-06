sealed class OnboardingEvent {}

/// Open the picker: load every translation the API offers.
class EditionsRequested extends OnboardingEvent {}

/// The user chose a translation. Kicks off the background sync.
class LanguageSelected extends OnboardingEvent {
  LanguageSelected(this.edition);
  final String edition;
}

class SyncProgressed extends OnboardingEvent {
  SyncProgressed(this.fraction);
  final double fraction;
}

class SyncFinished extends OnboardingEvent {}

class SyncFailed extends OnboardingEvent {
  SyncFailed(this.error);
  final Object error;
}
