import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/notifications/state/notifications_notifier.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// One destination of a [TabShell].
class TabItem {
  const TabItem({required this.icon, required this.label, this.badge});

  final IconData icon;
  final String label;

  /// A count shown on the icon; null or zero shows nothing.
  final int? badge;
}

/// The frame of an area of the app: a bottom bar whose destinations each
/// keep their own history.
class TabShell extends StatelessWidget {
  const TabShell({
    required this.navigationShell,
    required this.items,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final List<TabItem> items;

  @override
  Widget build(BuildContext context) {
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
            for (final item in items)
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: (item.badge ?? 0) > 0,
                  backgroundColor: colors.danger.solid,
                  textColor: colors.onPrimary,
                  label: Text('${item.badge}'),
                  child: Icon(item.icon),
                ),
                label: item.label,
              ),
          ],
        ),
      ),
    );
  }
}

/// The customer area.
class CustomerShell extends ConsumerWidget {
  const CustomerShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return TabShell(
      navigationShell: navigationShell,
      items: [
        TabItem(icon: Icons.explore_outlined, label: l10n.tabExplore),
        TabItem(icon: Icons.event_note_outlined, label: l10n.tabBookings),
        TabItem(
          icon: Icons.notifications_outlined,
          label: l10n.tabActivity,
          badge: unread,
        ),
        TabItem(icon: Icons.person_outline, label: l10n.tabProfile),
      ],
    );
  }
}

/// The owner area: its own destinations, never squeezed into the
/// customer's tabs.
class OwnerShell extends StatelessWidget {
  const OwnerShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return TabShell(
      navigationShell: navigationShell,
      items: [
        TabItem(icon: Icons.event_note_outlined, label: l10n.ownerTabBookings),
        TabItem(
          icon: Icons.local_parking_outlined,
          label: l10n.ownerTabFacilities,
        ),
        TabItem(
          icon: Icons.account_balance_wallet_outlined,
          label: l10n.ownerTabEarnings,
        ),
      ],
    );
  }
}
