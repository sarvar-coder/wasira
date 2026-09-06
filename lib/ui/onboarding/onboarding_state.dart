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

class OnboardingReady extends OnboardingState {
  OnboardingReady(this.edition);
  final String edition;
}
