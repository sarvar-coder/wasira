import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/daily_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../domain/ayah_citation.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/tokens.dart';
import '../daily_bloc.dart';
import '../daily_event.dart';
import '../daily_state.dart';
import 'ayah_view.dart';

/// The whole app: one ayah, for today.
class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<DailyBloc, DailyState>(
        builder: (context, state) => switch (state) {
          DailyLoading() => const Center(child: CircularProgressIndicator()),
          DailyUnavailable(:final error) => _Unavailable(error: error),
          final DailyLoaded loaded => _Ayah(state: loaded),
        },
      );
}

/// The app needs the network once a day. This is that once, and it failed.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    final tokens = Tokens.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.serviceUnreachable,
                textAlign: TextAlign.center,
                style: TextStyle(color: tokens.muted)),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => context.read<DailyBloc>().add(DailyRetried()),
              child: Text(l10n.tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ayah extends StatelessWidget {
  const _Ayah({required this.state});
  final DailyLoaded state;

  @override
  Widget build(BuildContext context) {
    final tokens = Tokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final daily = state.daily;
    final reference =
        ayahReference(daily.surah.number, daily.ayah.numberInSurah);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${daily.surah.nameEn}  ·  $reference',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: tokens.muted),
                  ),
                ),
                _CopyButton(daily: daily),
                IconButton(
                  icon: const Icon(Icons.tune, size: 18),
                  tooltip: l10n.dailySettings,
                  onPressed: () => _openSettings(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: AyahView(
                ayah: daily.ayah,
                arabicSize: state.arabicSize,
                translation: daily.translation,
                expanded: state.expanded,
                onExpand: () =>
                    context.read<DailyBloc>().add(TranslationExpanded()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.daily});
  final DailyAyah daily;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      icon: const Icon(Icons.copy_all_outlined, size: 17),
      tooltip: l10n.copyAyah,
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        await Clipboard.setData(ClipboardData(
          text: ayahCitation(
            arabic: daily.ayah.textAr,
            translation: daily.translation,
            surahName: daily.surah.nameEn,
            surah: daily.surah.number,
            numberInSurah: daily.ayah.numberInSurah,
          ),
        ));
        messenger.showSnackBar(SnackBar(
          content: Text(l10n.copied),
          duration: const Duration(seconds: 2),
        ));
      },
    );
  }
}

Future<void> _openSettings(BuildContext context) {
  final bloc = context.read<DailyBloc>();
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: const _SettingsDialog(),
    ),
  );
}

/// Arabic size and the five reminder times. Nothing else is configurable,
/// because nothing else exists.
class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Tokens.of(context);

    return BlocBuilder<DailyBloc, DailyState>(
      builder: (context, state) {
        if (state is! DailyLoaded) return const SizedBox.shrink();
        final bloc = context.read<DailyBloc>();

        return AlertDialog(
          title: Text(l10n.dailySettings, style: const TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.arabicTextSize,
                  style: TextStyle(fontSize: 12, color: tokens.muted)),
              const SizedBox(height: 8),
              SegmentedButton<double>(
                showSelectedIcon: false,
                segments: [
                  for (final size in SettingsRepository.arabicSizes)
                    ButtonSegment(
                        value: size, label: Text('${size.round()}')),
                ],
                selected: {state.arabicSize},
                onSelectionChanged: (s) =>
                    bloc.add(ArabicSizeChanged(s.first)),
              ),
              const SizedBox(height: 20),
              Text(l10n.reminders,
                  style: TextStyle(fontSize: 12, color: tokens.muted)),
              // One ayah, five nudges — the count of reminders has nothing to
              // do with the count of ayahs.
              Wrap(
                children: [
                  for (var i = 0; i < state.reminderTimes.length; i++)
                    _ReminderChip(index: i, minutes: state.reminderTimes[i]),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        );
      },
    );
  }
}

class _ReminderChip extends StatelessWidget {
  const _ReminderChip({required this.index, required this.minutes});
  final int index;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

    return TextButton(
      onPressed: () async {
        final bloc = context.read<DailyBloc>();
        final picked =
            await showTimePicker(context: context, initialTime: time);
        if (picked != null) {
          bloc.add(
              ReminderTimeChanged(index, picked.hour * 60 + picked.minute));
        }
      },
      child: Text(time.format(context)),
    );
  }
}
