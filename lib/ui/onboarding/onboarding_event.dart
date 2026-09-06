sealed class OnboardingEvent {}

/// Open the picker: load every translation the API offers.
class EditionsRequested extends OnboardingEvent {}

/// The user chose a translation. Nothing downloads — the ayah of the day is
/// fetched when the day needs it.
class LanguageSelected extends OnboardingEvent {
  LanguageSelected(this.edition);
  final String edition;
}
