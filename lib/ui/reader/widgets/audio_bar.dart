import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/services/audio_player_service.dart';
import '../../../domain/reciter.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/tokens.dart';
import '../audio_bloc.dart';
import '../audio_event.dart';
import '../audio_state.dart';

/// Pinned to the bottom of the reader while a surah is open.
///
/// For al-Luhaidan the ayah-level controls are shown **disabled with a reason**
/// rather than hidden: a control that silently vanishes reads as a bug, while a
/// disabled one with a tooltip explains why the reciter cannot do it.
class AudioBar extends StatelessWidget {
  const AudioBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Tokens.of(context);
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<AudioBloc, AudioState>(
      builder: (context, state) {
        final bloc = context.read<AudioBloc>();
        final ayahControls = state.ayahControlsApply;
        final reason = ayahControls ? null : l10n.wholeSurahReciter;

        return Material(
          color: tokens.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Divider(height: 1, color: tokens.divider),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text('${l10n.playbackFailed}: ${state.error}',
                      style: TextStyle(fontSize: 12, color: tokens.muted)),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    _Control(
                      icon: Icons.skip_previous,
                      tooltip: reason ?? l10n.previousAyah,
                      enabled: ayahControls,
                      onPressed: () => bloc.add(PreviousAyahRequested()),
                    ),
                    _Control(
                      icon: state.playing ? Icons.pause : Icons.play_arrow,
                      tooltip: state.playing ? l10n.pause : l10n.play,
                      enabled: true,
                      onPressed: () => bloc.add(
                          state.playing ? PlaybackPaused() : PlaybackRequested()),
                    ),
                    _Control(
                      icon: Icons.skip_next,
                      tooltip: reason ?? l10n.nextAyah,
                      enabled: ayahControls,
                      onPressed: () => bloc.add(NextAyahRequested()),
                    ),
                    const SizedBox(width: 8),
                    _RepeatButton(
                        state: state, enabled: ayahControls, reason: reason),
                    const Spacer(),
                    // Flexible: on a phone-width window the controls and
                    // "Mishary Rashid Alafasy" do not both fit, and the name
                    // is what can give.
                    Flexible(child: _ReciterButton(state: state)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: IconButton(
          icon: Icon(icon, size: 22),
          onPressed: enabled ? onPressed : null,
        ),
      );
}

/// Repeating one ayah, then a span, is how hifz works — this is the seed of
/// the memorization feature rather than a playback nicety.
class _RepeatButton extends StatelessWidget {
  const _RepeatButton(
      {required this.state, required this.enabled, required this.reason});

  final AudioState state;
  final bool enabled;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final tokens = Tokens.of(context);
    final l10n = AppLocalizations.of(context)!;

    String label(RecitationRepeat mode) => switch (mode) {
          RecitationRepeat.none => l10n.repeatOff,
          RecitationRepeat.ayah => l10n.repeatAyah,
          RecitationRepeat.range => l10n.repeatRange,
        };

    return Tooltip(
      message: reason ?? label(state.repeat),
      child: PopupMenuButton<RecitationRepeat>(
        enabled: enabled,
        icon: Icon(
          state.repeat == RecitationRepeat.ayah ? Icons.repeat_one : Icons.repeat,
          size: 20,
          color: state.repeat == RecitationRepeat.none ? null : tokens.accent,
        ),
        onSelected: (mode) =>
            context.read<AudioBloc>().add(RecitationRepeatChanged(mode)),
        itemBuilder: (context) => [
          for (final mode in RecitationRepeat.values)
            PopupMenuItem(
              value: mode,
              child: Text(label(mode), style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

class _ReciterButton extends StatelessWidget {
  const _ReciterButton({required this.state});
  final AudioState state;

  @override
  Widget build(BuildContext context) {
    final tokens = Tokens.of(context);

    return PopupMenuButton<Reciter>(
      tooltip: AppLocalizations.of(context)!.reciter,
      onSelected: (r) => context.read<AudioBloc>().add(ReciterChanged(r)),
      itemBuilder: (context) => [
        for (final reciter in Reciter.all)
          PopupMenuItem(
            value: reciter,
            child: Row(
              children: [
                Expanded(
                    child: Text(reciter.name,
                        style: const TextStyle(fontSize: 13))),
                if (reciter.edition == state.reciter.edition)
                  Icon(Icons.check, size: 16, color: tokens.accent),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(state.reciter.name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: tokens.muted)),
      ),
    );
  }
}
