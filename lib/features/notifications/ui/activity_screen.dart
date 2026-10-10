import 'package:app/app/routes.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/cursor_list_view.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/features/notifications/data/models/app_notification.dart';
import 'package:app/features/notifications/state/notifications_notifier.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  /// Notification types sent to the owner of a facility. Everything else
  /// about a booking is opened as the customer's booking.
  static const _ownerTypes = {'booking.approval_requested'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);
    final hasUnread = state.items.any((item) => !item.isRead);

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
        state: state,
        onRefresh: notifier.load,
        onLoadMore: notifier.loadMore,
        empty: EmptyState(
          icon: Icons.notifications_none_outlined,
          title: l10n.activityEmptyTitle,
          body: l10n.activityEmptyBody,
        ),
        itemBuilder: (context, notification) => _NotificationCard(
          notification: notification,
          onTap: () {
            notifier.markRead(notification);
            final bookingId = notification.bookingId;
            if (bookingId != null) {
              context.push(
                _ownerTypes.contains(notification.type)
                    ? Routes.ownerBooking(bookingId)
                    : Routes.booking(bookingId),
              );
            }
          },
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
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
            // Unread is a dot and bolder title: never colour alone.
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.sm),
              child: Container(
                width: AppSpace.sm,
                height: AppSpace.sm,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: notification.isRead
                      ? Colors.transparent
                      : colors.primary,
                ),
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
