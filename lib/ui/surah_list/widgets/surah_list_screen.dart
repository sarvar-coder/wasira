import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/surah.dart';
import '../../core/themes/tokens.dart';
import '../surah_list_bloc.dart';
import '../surah_list_event.dart';
import '../surah_list_state.dart';

/// The 114 surahs. Stays scrollable while the background sync runs — that is
/// the whole point of painting this from a 19 KB request.
class SurahListScreen extends StatelessWidget {
  const SurahListScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SurahListBloc, SurahListState>(
        builder: (context, state) => switch (state) {
          SurahListLoading() => const Center(child: CircularProgressIndicator()),
          SurahListFailed(:final error) => Center(
              child: Text('Could not load surahs: $error',
                  style: TextStyle(color: Tokens.of(context).muted)),
            ),
          SurahListLoaded(:final surahs) => ListView.builder(
              itemCount: surahs.length,
              itemBuilder: (context, i) => _SurahTile(surah: surahs[i]),
            ),
        },
      );
}

class _SurahTile extends StatelessWidget {
  const _SurahTile({required this.surah});
  final Surah surah;

  @override
  Widget build(BuildContext context) {
    final tokens = Tokens.of(context);

    return ListTile(
      leading: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('${surah.number}',
            style: TextStyle(
                color: tokens.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
      title: Text(surah.nameEn),
      subtitle: Text(
        '${surah.nameEnTranslation}  ·  ${surah.ayahCount} ayahs  ·  ${surah.revelationType}',
        style: TextStyle(color: tokens.muted, fontSize: 12),
      ),
      trailing: Directionality(
        textDirection: TextDirection.rtl,
        child: Text(surah.nameAr, style: const TextStyle(fontSize: 17)),
      ),
      onTap: () => context.read<SurahListBloc>().add(SurahOpened(surah.number)),
    );
  }
}
