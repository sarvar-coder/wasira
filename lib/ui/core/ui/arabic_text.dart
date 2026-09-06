import 'package:flutter/material.dart';

/// Quranic Arabic. Always right-to-left regardless of the app's UI language,
/// and always generously leaded: Uthmani tashkeel collides below a line height
/// of about 2.0.
///
/// The font is locked by ADR-0002. Changing it means re-running the M0 goldens,
/// because a different face can silently lack a rare Quranic mark.
class ArabicText extends StatelessWidget {
  const ArabicText(
    this.text, {
    super.key,
    this.size = 30,
    this.color,
    this.align = TextAlign.right,
  });

  static const fontFamily = 'AmiriQuran';
  static const lineHeight = 2.0;

  final String text;
  final double size;
  final Color? color;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SelectableText(
          text,
          textAlign: align,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: size,
            height: lineHeight,
            color: color ?? Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      );
}
