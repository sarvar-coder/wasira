import 'package:flutter/material.dart';

/// Warm neutrals rather than blue-greys: parchment, not office software.
/// The text is the interface, so the surface stays quiet.
class Tokens {
  const Tokens({
    required this.bg,
    required this.surface,
    required this.text,
    required this.muted,
    required this.accent,
    required this.divider,
  });

  final Color bg;
  final Color surface;
  final Color text;
  final Color muted;
  final Color accent;
  final Color divider;

  static const light = Tokens(
    bg: Color(0xFFFAF8F4),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF1C1917),
    muted: Color(0xFF78716C),
    accent: Color(0xFF0F5132),
    divider: Color(0xFFE7E5E4),
  );

  static const dark = Tokens(
    bg: Color(0xFF14130F),
    surface: Color(0xFF1E1C18),
    text: Color(0xFFF5F3EF),
    muted: Color(0xFFA8A29E),
    accent: Color(0xFF5EAD8A),
    divider: Color(0xFF2C2A26),
  );

  static Tokens of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  ThemeData get theme => ThemeData(
        brightness: bg.computeLuminance() > 0.5 ? Brightness.light : Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: bg.computeLuminance() > 0.5 ? Brightness.light : Brightness.dark,
        ).copyWith(surface: surface),
        dividerColor: divider,
        useMaterial3: true,
      );
}
