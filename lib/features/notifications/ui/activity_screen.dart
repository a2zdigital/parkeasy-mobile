import 'dart:async';

import 'package:app/core/state/cursor_list.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_filter_chip.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/cursor_list_view.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/features/auth/data/models/user_role.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:app/features/auth/state/session_state.dart';
import 'package:app/features/notifications/data/models/activity_category.dart';
import 'package:app/features/notifications/data/models/app_notification.dart';
import 'package:app/features/notifications/state/notifications_notifier.dart';
import 'package:app/features/notifications/ui/notification_route.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum _ActivityFilter { all, bookings, facilities, payments, account }

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  _ActivityFilter _filter = _ActivityFilter.all;
  bool _loadingPastFilteredPages = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);
    final session = ref.watch(sessionControllerProvider);
    final roles = switch (session) {
      SignedIn(:final user) => user.roles,
      _ => const <UserRole>[],
    };
    final visibleItems = state.items
        .where((item) => item.isVisibleToRoles(roles))
        .toList();
    final filteredItems = visibleItems
        .where((item) => _matchesFilter(item, _filter))
        .toList();
    final hasUnread = visibleItems.any((item) => !item.isRead);
    final shouldLoadMore =
        filteredItems.isEmpty &&
        state.hasMore &&
        !state.isLoading &&
        !state.isLoadingMore &&
        state.loadMoreFailure == null;

    if (shouldLoadMore) _loadPastFilteredPages(notifier);

    final filteredState = CursorListState<AppNotification>(
      items: filteredItems,
      isLoading: state.isLoading || state.isLoadingMore || shouldLoadMore,
      failure:
          state.failure ??
          (filteredItems.isEmpty ? state.loadMoreFailure : null),
      nextCursor: state.nextCursor,
      hasMore: state.hasMore,
      isLoadingMore: state.isLoadingMore,
      loadMoreFailure: state.loadMoreFailure,
    );

    return AppScaffold(
      title: l10n.tabActivity,
      scrollable: false,
      actions: [
        if (hasUnread)
          TextButton(
            onPressed: notifier.markAllRead,
            child: Text(l10n.activityMarkAllRead),
          ),
      ],
      body: CursorListView<AppNotification>(
        state: filteredState,
        onRefresh: notifier.load,
        onLoadMore: notifier.loadMore,
        empty: EmptyState(
          icon: _emptyIcon(_filter),
          title: _emptyTitle(l10n, _filter),
          body: _emptyBody(l10n, _filter),
        ),
        header: _ActivityFilters(
          selected: _filter,
          onSelected: (filter) => setState(() => _filter = filter),
        ),
        itemBuilder: (context, notification) => _NotificationCard(
          notification: notification,
          icon: _notificationIcon(notification),
          onTap: () {
            notifier.markRead(notification);
            final destination = notificationDestination(notification);
            if (destination == null) return;
            if (destination.isTab) {
              context.go(destination.route);
            } else {
              context.push(destination.route);
            }
          },
        ),
      ),
    );
  }

  bool _matchesFilter(AppNotification notification, _ActivityFilter filter) {
    if (filter == _ActivityFilter.all) return true;
    final category = notification.activityCategory;
    return switch (filter) {
      _ActivityFilter.all => true,
      _ActivityFilter.bookings => category == ActivityCategory.bookings,
      _ActivityFilter.facilities => category == ActivityCategory.facilities,
      _ActivityFilter.payments => category == ActivityCategory.payments,
      _ActivityFilter.account => category == ActivityCategory.account,
    };
  }

  void _loadPastFilteredPages(NotificationsNotifier notifier) {
    if (_loadingPastFilteredPages) return;
    _loadingPastFilteredPages = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        notifier.loadMore().whenComplete(() {
          if (!mounted) return;
          setState(() => _loadingPastFilteredPages = false);
        }),
      );
    });
  }

  String _emptyTitle(AppLocalizations l10n, _ActivityFilter filter) =>
      switch (filter) {
        _ActivityFilter.all => l10n.activityEmptyTitle,
        _ActivityFilter.bookings => l10n.activityEmptyBookingsTitle,
        _ActivityFilter.facilities => l10n.activityEmptyFacilitiesTitle,
        _ActivityFilter.payments => l10n.activityEmptyPaymentsTitle,
        _ActivityFilter.account => l10n.activityEmptyAccountTitle,
      };

  String _emptyBody(AppLocalizations l10n, _ActivityFilter filter) =>
      switch (filter) {
        _ActivityFilter.all => l10n.activityEmptyBody,
        _ActivityFilter.bookings => l10n.activityEmptyBookingsBody,
        _ActivityFilter.facilities => l10n.activityEmptyFacilitiesBody,
        _ActivityFilter.payments => l10n.activityEmptyPaymentsBody,
        _ActivityFilter.account => l10n.activityEmptyAccountBody,
      };

  IconData _emptyIcon(_ActivityFilter filter) => switch (filter) {
    _ActivityFilter.all => Icons.notifications_none_outlined,
    _ActivityFilter.bookings => Icons.calendar_today_outlined,
    _ActivityFilter.facilities => Icons.local_parking_outlined,
    _ActivityFilter.payments => Icons.payments_outlined,
    _ActivityFilter.account => Icons.person_outline,
  };
}

class _ActivityFilters extends StatelessWidget {
  const _ActivityFilters({required this.selected, required this.onSelected});

  final _ActivityFilter selected;
  final ValueChanged<_ActivityFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = {
      _ActivityFilter.all: l10n.activityCategoryAll,
      _ActivityFilter.bookings: l10n.activityCategoryBookings,
      _ActivityFilter.facilities: l10n.activityCategoryFacilities,
      _ActivityFilter.payments: l10n.activityCategoryPayments,
      _ActivityFilter.account: l10n.activityCategoryAccount,
    };

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm, bottom: AppSpace.md),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final filter in _ActivityFilter.values) ...[
              if (filter != _ActivityFilter.all) const Gap.sm(),
              AppFilterChip(
                label: labels[filter]!,
                isSelected: selected == filter,
                onPressed: () => onSelected(filter),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.icon,
    required this.onTap,
  });

  final AppNotification notification;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final when = DateFormat(
      'd MMM, h:mm a',
      locale,
    ).format(notification.createdAt.toLocal());

    return Semantics(
      button: true,
      label: notification.isRead ? null : l10n.activityUnread,
      child: AppCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: AppSize.touchTarget,
              height: AppSize.touchTarget,
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      width: AppSize.iconTile,
                      height: AppSize.iconTile,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: AppRadius.controlAll,
                      ),
                      child: Icon(
                        icon,
                        size: AppSize.iconSmall,
                        color: colors.primaryPressed,
                      ),
                    ),
                  ),
                  if (!notification.isRead)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: AppSpace.sm,
                        height: AppSpace.sm,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary,
                          border: Border.all(
                            color: colors.surface,
                            width: AppSize.borderWidth,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Gap.md(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: text.body.copyWith(
                      fontWeight: notification.isRead
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                  ),
                  const Gap.xs(),
                  Text(
                    notification.body,
                    style: text.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                  const Gap.sm(),
                  Text(
                    when,
                    style: text.label.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _notificationIcon(AppNotification notification) {
  final type = notification.type.toLowerCase();
  if (type.contains('check_in')) return Icons.login;
  if (type.contains('check_out')) return Icons.logout;
  if (type.contains('cancel') || type.contains('reject')) {
    return Icons.event_busy_outlined;
  }
  if (type.contains('refund')) return Icons.currency_exchange;
  if (type.startsWith('payout.')) return Icons.account_balance_wallet_outlined;

  return switch (notification.activityCategory) {
    ActivityCategory.bookings => Icons.calendar_today_outlined,
    ActivityCategory.facilities => Icons.local_parking_outlined,
    ActivityCategory.payments => Icons.payments_outlined,
    ActivityCategory.account => Icons.person_outline,
    null => Icons.notifications_none_outlined,
  };
}
