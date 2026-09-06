import '../../domain/models/edition.dart';

sealed class OnboardingState {}

class OnboardingLoading extends OnboardingState {}

class OnboardingFailed extends OnboardingState {
  OnboardingFailed(this.error);
  final Object error;
}

/// Editions loaded, waiting for the user to pick one.
class OnboardingChoosing extends OnboardingState {
  OnboardingChoosing(this.editions);
  final List<Edition> editions;
}

/// A language is chosen and the Quran is downloading in the background. The
/// surah list is already usable at this point — this is not a blocking screen.
class OnboardingSyncing extends OnboardingState {
  OnboardingSyncing(this.edition, this.progress);
  final String edition;
  final double progress;
}

class OnboardingReady extends OnboardingState {
  OnboardingReady(this.edition);
  final String edition;
}
