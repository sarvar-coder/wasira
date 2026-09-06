import 'package:flutter/material.dart';

import '../../../domain/models/ayah.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/tokens.dart';
import '../../core/ui/arabic_text.dart';

class AyahTile extends StatelessWidget {
  const AyahTile({
    super.key,
    required this.ayah,
    required this.arabicSize,
    this.translation,
    this.translationDirection = TextDirection.ltr,
    this.expanded = false,
    this.onExpand,
    this.highlighted = false,
  });

  /// Past this many characters a translation is clamped. uz.sodik is a
  /// tafsir-translation whose entries reach 2660 characters, which buries the
  /// ayah it belongs to.
  static const clampThreshold = 300;

  final Ayah ayah;
  final double arabicSize;
  final String? translation;
  final TextDirection translationDirection;
  final bool expanded;
  final VoidCallback? onExpand;

  /// True while this ayah is the one sounding. Never true for a surah-by-surah
  /// reciter, which cannot report ayah position.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final tokens = Tokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final long = (translation?.length ?? 0) > clampThreshold;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      color: highlighted
          ? tokens.accent.withValues(alpha: 0.06)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _NumberBadge(number: ayah.numberInSurah, tokens: tokens),
              if (ayah.sajda) ...[
                const SizedBox(width: 8),
                _SajdaMark(ayah: ayah, tokens: tokens, l10n: l10n),
              ],
            ],
          ),
          const SizedBox(height: 10),
          ArabicText(ayah.textAr, size: arabicSize),
          if (translation != null && translation!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Directionality(
              textDirection: translationDirection,
              child: Text(
                translation!,
                maxLines: long && !expanded ? 3 : null,
                overflow:
                    long && !expanded ? TextOverflow.ellipsis : TextOverflow.clip,
                style: TextStyle(
                    color: tokens.muted, fontSize: 14, height: 1.55),
              ),
            ),
            if (long && !expanded)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: onExpand,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l10n.showMore,
                      style: TextStyle(fontSize: 12, color: tokens.accent)),
                ),
              ),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, color: tokens.divider),
        ],
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number, required this.tokens});
  final int number;
  final Tokens tokens;

  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$number',
            style: TextStyle(
                color: tokens.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );
}

/// One of the 15 ayahs of prostration. The API classifies 4 as obligatory and
/// 11 as recommended; that split varies by madhhab, so the label reports the
/// classification rather than issuing a ruling.
class _SajdaMark extends StatelessWidget {
  const _SajdaMark(
      {required this.ayah, required this.tokens, required this.l10n});
  final Ayah ayah;
  final Tokens tokens;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: ayah.sajdaObligatory == true
            ? l10n.sajdaObligatoryHere
            : l10n.sajdaHere,
        child: Text(
          '۩',
          style: TextStyle(
            fontFamily: ArabicText.fontFamily,
            fontSize: 18,
            color: ayah.sajdaObligatory == true ? tokens.accent : tokens.muted,
          ),
        ),
      );
}
