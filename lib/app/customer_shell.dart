import 'package:app/core/theme/app_theme.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The customer area: four destinations, each keeping its own history.
class CustomerShell extends StatelessWidget {
  const CustomerShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final text = context.text;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: colors.surface,
          surfaceTintColor: colors.surface,
          indicatorColor: colors.primaryContainer,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => text.label.copyWith(
              color: states.contains(WidgetState.selected)
                  ? colors.primary
                  : colors.textSecondary,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? colors.primary
                  : colors.textSecondary,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          // Pressing the current tab returns to its first screen.
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.explore_outlined),
              label: l10n.tabExplore,
            ),
            NavigationDestination(
              icon: const Icon(Icons.event_note_outlined),
              label: l10n.tabBookings,
            ),
            NavigationDestination(
              icon: const Icon(Icons.notifications_outlined),
              label: l10n.tabActivity,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              label: l10n.tabProfile,
            ),
          ],
        ),
      ),
    );
  }
}
