import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/reciter.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/tokens.dart';
import '../downloads_bloc.dart';
import '../downloads_event.dart';
import '../downloads_state.dart';

/// Recitation on disk, per surah and per reciter.
///
/// Required in v1 rather than a nicety: three reciters over a few surahs runs
/// to gigabytes, and without this there is no way to get it back.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<DownloadsBloc, DownloadsState>(
        builder: (context, state) => switch (state) {
          DownloadsLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          DownloadsFailed(:final error) => Center(
            child: Text(
              '${AppLocalizations.of(context)!.surahsUnavailable}: $error',
              style: TextStyle(color: Tokens.of(context).muted),
            ),
          ),
          final DownloadsLoaded loaded => Column(
            children: [
              _Header(state: loaded),
              Divider(height: 1, color: Tokens.of(context).divider),
              Expanded(
                child: ListView.builder(
                  itemCount: loaded.rows.length,
                  itemBuilder: (context, i) => _SurahRow(row: loaded.rows[i]),
                ),
              ),
            ],
          ),
        },
      );
}

/// Powers of 1000 with one decimal, the way macOS reports disk. A surah runs
/// from a few hundred KB to 55 MB, and a whole reciter to well over a GB.
String formatBytes(int bytes) {
  if (bytes >= 1000000000) {
    return '${(bytes / 1000000000).toStringAsFixed(2)} GB';
  }
  if (bytes >= 1000000) return '${(bytes / 1000000).toStringAsFixed(1)} MB';
  return '${(bytes / 1000).round()} KB';
}

class _Header extends StatelessWidget {
  const _Header({required this.state});
  final DownloadsLoaded state;

  @override
  Widget build(BuildContext context) {
    final tokens = Tokens.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          // Flexible, not Expanded: the picker keeps a tap area the size of the
          // name, but gives way to the size figure on a narrow window.
          Flexible(
            child: PopupMenuButton<Reciter>(
              tooltip: l10n.reciter,
              onSelected: (r) =>
                  context.read<DownloadsBloc>().add(DownloadsReciterChanged(r)),
              itemBuilder: (context) => [
                for (final reciter in Reciter.all)
                  PopupMenuItem(
                    value: reciter,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            reciter.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        if (reciter.edition == state.reciter.edition)
                          Icon(Icons.check, size: 16, color: tokens.accent),
                      ],
                    ),
                  ),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ellipsised rather than allowed to overflow: on a phone-width
                  // window "Muhammad al-Luhaidan" and a GB figure do not both fit.
                  Flexible(
                    child: Text(
                      state.reciter.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 20, color: tokens.muted),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            l10n.storageUsed(formatBytes(state.bytes)),
            style: TextStyle(fontSize: 12, color: tokens.muted),
          ),
        ],
      ),
    );
  }
}

class _SurahRow extends StatelessWidget {
  const _SurahRow({required this.row});
  final SurahDownload row;

  @override
  Widget build(BuildContext context) {
    final tokens = Tokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<DownloadsBloc>();

    final subtitle = switch (row) {
      SurahDownload(:final error?) => '${l10n.downloadFailed}: $error',
      SurahDownload(downloading: true) when row.total > 1 =>
        '${row.done} / ${row.total}',
      SurahDownload(bytes: > 0) => formatBytes(row.bytes),
      _ => l10n.ayahCount(row.surah.ayahCount),
    };

    return ListTile(
      dense: true,
      leading: SizedBox(
        width: 34,
        child: Text(
          '${row.surah.number}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: tokens.muted),
        ),
      ),
      title: Text(row.surah.nameEn, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: row.error == null ? tokens.muted : tokens.accent,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (row.downloading)
            SizedBox(
              width: 18,
              height: 18,
              // A surah-by-surah reciter is one file, so there is no ratio to
              // show until it lands.
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: row.total > 1 ? row.done / row.total : null,
              ),
            )
          else if (!row.complete)
            IconButton(
              icon: const Icon(Icons.download_outlined, size: 20),
              tooltip: row.partial ? l10n.resumeDownload : l10n.download,
              onPressed: () =>
                  bloc.add(SurahDownloadRequested(row.surah.number)),
            ),
          if (row.bytes > 0 && !row.downloading)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: l10n.deleteDownload,
              onPressed: () => bloc.add(SurahDownloadDeleted(row.surah.number)),
            ),
        ],
      ),
    );
  }
}
