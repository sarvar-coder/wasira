import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/edition.dart';
import '../../core/themes/tokens.dart';
import '../onboarding_bloc.dart';
import '../onboarding_event.dart';
import '../onboarding_state.dart';

/// The language picker. Every translation the API offers, grouped by language.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Tokens.of(context);

    return BlocBuilder<OnboardingBloc, OnboardingState>(
      builder: (context, state) => switch (state) {
        OnboardingLoading() => const Center(child: CircularProgressIndicator()),
        OnboardingFailed(:final error) => _Failed(error: error),
        OnboardingChoosing(:final editions) =>
          _Picker(editions: editions, tokens: tokens),
        // Once a language is chosen the app moves on immediately; the download
        // continues behind the surah list rather than behind a spinner.
        OnboardingSyncing() || OnboardingReady() => const SizedBox.shrink(),
      },
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not reach the Quran service',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('$error',
                style: TextStyle(color: Tokens.of(context).muted, fontSize: 12)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  context.read<OnboardingBloc>().add(EditionsRequested()),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
}

class _Picker extends StatelessWidget {
  const _Picker({required this.editions, required this.tokens});
  final List<Edition> editions;
  final Tokens tokens;

  @override
  Widget build(BuildContext context) {
    final byLanguage = <String, List<Edition>>{};
    for (final e in editions) {
      byLanguage.putIfAbsent(e.language, () => []).add(e);
    }
    final languages = byLanguage.keys.toList()..sort();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose a translation',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                '${editions.length} translations in ${languages.length} languages. '
                'You can change this later.',
                style: TextStyle(color: tokens.muted),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: languages.length,
            itemBuilder: (context, i) {
              final language = languages[i];
              final group = byLanguage[language]!;
              return ExpansionTile(
                title: Text(language.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${group.length} available',
                    style: TextStyle(color: tokens.muted, fontSize: 12)),
                children: [
                  for (final e in group)
                    ListTile(
                      title: Text(e.englishName),
                      subtitle: Text(e.name,
                          style: TextStyle(color: tokens.muted, fontSize: 12)),
                      onTap: () => context
                          .read<OnboardingBloc>()
                          .add(LanguageSelected(e.identifier)),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
