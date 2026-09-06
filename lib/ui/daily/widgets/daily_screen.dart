import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/tokens.dart';
import '../../reader/widgets/ayah_tile.dart';
import '../daily_bloc.dart';
import '../daily_event.dart';
import '../daily_state.dart';

/// A few ayahs a day, and the calendar of the days already given.
class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<DailyBloc, DailyState>(
    builder: (context, state) => switch (state) {
      DailyLoading() => const Center(child: CircularProgressIndicator()),
      DailyFailed(:final error) => _Message(text: '$error'),
      DailyWaitingForSync() => _Message(
        text: AppLocalizations.of(context)!.downloadingQuran,
      ),
      final DailyLoaded loaded => _Day(state: loaded),
    },
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(text, style: TextStyle(color: Tokens.of(context).muted)),
  );
}

class _Day extends StatelessWidget {
  const _Day({required this.state});
  final DailyLoaded state;

  @override
  Widget build(BuildContext context) {
    final tokens = Tokens.of(context);

    return Column(
      children: [
        _Header(state: state),
        Divider(height: 1, color: tokens.divider),
        Expanded(
          child: ListView.builder(
            itemCount: state.ayahs.length,
            itemBuilder: (context, i) {
              final daily = state.ayahs[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                    child: Text(
                      '${daily.surah.nameEn} · ${daily.ayah.numberInSurah}',
                      style: TextStyle(fontSize: 12, color: tokens.muted),
                    ),
                  ),
                  AyahTile(
                    ayah: daily.ayah,
                    arabicSize: state.arabicSize,
                    translation: daily.translation,
                    expanded: state.expanded.contains(daily.ayah.number),
                    onExpand: () => context.read<DailyBloc>().add(
                      TranslationExpanded(daily.ayah.number),
                    ),
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

class _Header extends StatelessWidget {
  const _Header({required this.state});
  final DailyLoaded state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isToday = _sameDay(state.date, DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 8, 12),
      child: Row(
        children: [
          Flexible(
            child: Text(
              isToday
                  ? l10n.today
                  : MaterialLocalizations.of(context).formatFullDate(state.date),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, size: 19),
            tooltip: l10n.pickADay,
            onPressed: () => _pickDay(context, state),
          ),
          IconButton(
            icon: const Icon(Icons.tune, size: 20),
            tooltip: l10n.dailySettings,
            onPressed: () => _openSettings(context, state),
          ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Material's own calendar, with `lastDate` set to today — which is what makes
/// a future day unreachable, rather than a check that has to be remembered.
Future<void> _pickDay(BuildContext context, DailyLoaded state) async {
  final bloc = context.read<DailyBloc>();
  final now = DateTime.now();
  final picked = await showDialog<DateTime>(
    context: context,
    builder: (context) => Dialog(
      child: SizedBox(
        width: 360,
        child: CalendarDatePicker(
          initialDate: state.date,
          firstDate: state.since,
          lastDate: now,
          onDateChanged: (date) => Navigator.of(context).pop(date),
        ),
      ),
    ),
  );
  if (picked != null) bloc.add(DaySelected(picked));
}

Future<void> _openSettings(BuildContext context, DailyLoaded state) {
  final bloc = context.read<DailyBloc>();
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: const _SettingsDialog(),
    ),
  );
}

/// Count and reminder times, and nothing else. Everything else about a day is
/// derived from the seed, so there is nothing else to offer.
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
              Text(
                l10n.ayahsPerDay,
                style: TextStyle(fontSize: 12, color: tokens.muted),
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (final count in SettingsRepository.dailyCounts)
                    ButtonSegment(value: count, label: Text('$count')),
                ],
                selected: {state.count},
                onSelectionChanged: (s) =>
                    bloc.add(DailyCountChanged(s.first)),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.reminders,
                style: TextStyle(fontSize: 12, color: tokens.muted),
              ),
              // One reminder per ayah: three ayahs is three notifications, not
              // one listing three.
              for (var i = 0; i < state.reminderTimes.length; i++)
                _ReminderRow(index: i, minutes: state.reminderTimes[i]),
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

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.index, required this.minutes});
  final int index;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: () async {
          final bloc = context.read<DailyBloc>();
          final picked = await showTimePicker(
            context: context,
            initialTime: time,
          );
          if (picked != null) {
            bloc.add(
              ReminderTimeChanged(index, picked.hour * 60 + picked.minute),
            );
          }
        },
        child: Text(time.format(context)),
      ),
    );
  }
}
