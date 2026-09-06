import 'package:flutter/material.dart';

import '../themes/tokens.dart';

/// Sidebar on a wide window, bottom tabs on a narrow one. macOS and iPad get
/// the desktop shape; phones later get tabs without a rewrite.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.destinations, this.banner});

  final List<ShellDestination> destinations;

  /// Optional strip above the content — used for sync progress, which must not
  /// block the list behind it.
  final Widget? banner;

  static const wideBreakpoint = 720.0;

  @override
  State<AppShell> createState() => _AppShellState();
}

class ShellDestination {
  const ShellDestination(this.label, this.icon, this.builder);
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final tokens = Tokens.of(context);
    final current = widget.destinations[index];

    final content = Column(
      children: [
        if (widget.banner != null) widget.banner!,
        Expanded(child: Builder(builder: current.builder)),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppShell.wideBreakpoint;
        if (!wide) {
          return Scaffold(
            body: content,
            bottomNavigationBar: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => index = i),
              destinations: [
                for (final d in widget.destinations)
                  NavigationDestination(icon: Icon(d.icon), label: d.label),
              ],
            ),
          );
        }
        return Scaffold(
          body: Row(
            children: [
              Container(
                width: 220,
                color: tokens.surface,
                child: SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      for (var i = 0; i < widget.destinations.length; i++)
                        ListTile(
                          selected: i == index,
                          selectedTileColor:
                              tokens.accent.withValues(alpha: 0.10),
                          leading: Icon(widget.destinations[i].icon, size: 18),
                          title: Text(widget.destinations[i].label,
                              style: const TextStyle(fontSize: 13)),
                          onTap: () => setState(() => index = i),
                        ),
                    ],
                  ),
                ),
              ),
              VerticalDivider(width: 1, color: tokens.divider),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }
}
