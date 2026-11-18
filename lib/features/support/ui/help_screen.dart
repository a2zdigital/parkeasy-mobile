import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/core/widgets/status_chip.dart';
import 'package:app/features/support/data/models/support_ticket.dart';
import 'package:app/features/support/state/support_providers.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The words and tone for a ticket's status.
(StatusTone, String) supportStatus(
  AppLocalizations l10n,
  SupportTicketStatus status,
) => switch (status) {
  SupportTicketStatus.open => (StatusTone.info, l10n.supportStatusOpen),
  SupportTicketStatus.inProgress => (
    StatusTone.warning,
    l10n.supportStatusInProgress,
  ),
  SupportTicketStatus.resolved => (
    StatusTone.success,
    l10n.supportStatusResolved,
  ),
  SupportTicketStatus.closed => (StatusTone.neutral, l10n.supportStatusClosed),
  SupportTicketStatus.unknown => (StatusTone.neutral, status.wire),
};

/// Help and support: the user's tickets, and a way to open a new one. Works
/// the same for customers and owners; the route decides which profile it
/// sits under.
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final tickets = ref.watch(supportTicketsProvider);
    final base = GoRouterState.of(context).matchedLocation;
    final locale = Localizations.localeOf(context).toLanguageTag();

    return AppScaffold(
      title: l10n.supportTitle,
      scrollable: false,
      bottom: PrimaryButton(
        label: l10n.supportNewTicket,
        onPressed: () => context.push('$base/new'),
      ),
      body: tickets.when(
        loading: () => const Column(
          children: [Gap.lg(), SkeletonCard(), Gap.md(), SkeletonCard()],
        ),
        error: (error, _) => Center(
          child: ErrorState(
            failure: error is ApiException
                ? error
                : const ApiException(code: ApiErrorCode.unknown),
            onRetry: () => ref.invalidate(supportTicketsProvider),
          ),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(supportTicketsProvider),
          child: list.isEmpty
              ? ListView(
                  children: [
                    EmptyState(
                      icon: Icons.support_agent_outlined,
                      title: l10n.supportEmptyTitle,
                      body: l10n.supportEmptyBody,
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Gap.sm(),
                  itemBuilder: (context, index) {
                    final ticket = list[index];
                    final (tone, label) = supportStatus(l10n, ticket.status);
                    return AppCard(
                      onTap: () => context.push('$base/${ticket.id}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ticket.subject,
                                  style: text.h3,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Gap.sm(),
                              StatusChip(tone: tone, label: label),
                            ],
                          ),
                          const Gap.xs(),
                          Text(
                            '${ticket.reference} · ${ticket.categoryLabel} · '
                            '${DateFormat.yMMMd(locale).format(ticket.lastMessageAt.toLocal())}',
                            style: text.bodySmall.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
