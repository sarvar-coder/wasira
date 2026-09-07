sealed class OnboardingEvent {}

/// Open the picker: load every translation the API offers.
class EditionsRequested extends OnboardingEvent {}

/// The user chose a translation. Nothing downloads — the ayah of the day is
/// fetched when the day needs it.
class LanguageSelected extends OnboardingEvent {
  LanguageSelected(this.edition, [this.name]);
  final String edition;

  /// The edition's English name, remembered so settings can name it later.
  final String? name;
}
