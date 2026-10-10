import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/cursor_list_view.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/core/widgets/status_chip.dart';
import 'package:app/features/owner/data/models/approval_status.dart';
import 'package:app/features/owner/data/models/owner_parking_lot.dart';
import 'package:app/features/owner/state/owner_lists.dart';
import 'package:app/features/owner/ui/owner_common.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The owner's facilities and where each stands in review. Read-only:
/// creating and editing a facility is not built in the app yet.
class OwnerFacilitiesScreen extends ConsumerWidget {
  const OwnerFacilitiesScreen({super.key});

  static (String, StatusTone) _status(
    AppLocalizations l10n,
    OwnerParkingLot facility,
  ) => switch (facility.approvalStatus) {
    ApprovalStatus.approved when !facility.isActive => (
      l10n.facilityInactive,
      StatusTone.neutral,
    ),
    ApprovalStatus.approved => (l10n.facilityApproved, StatusTone.success),
    ApprovalStatus.pending => (l10n.facilityPending, StatusTone.warning),
    ApprovalStatus.rejected => (l10n.facilityRejected, StatusTone.danger),
    ApprovalStatus.draft ||
    ApprovalStatus.unknown => (l10n.facilityDraft, StatusTone.neutral),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(ownerFacilitiesProvider);
    final notifier = ref.read(ownerFacilitiesProvider.notifier);

    return AppScaffold(
      title: l10n.ownerTabFacilities,
      actions: const [ExitOwnerAreaAction()],
      scrollable: false,
      body: CursorListView<OwnerParkingLot>(
        state: state,
        onRefresh: notifier.load,
        onLoadMore: notifier.loadMore,
        errorText: (failure) => ownerAccessText(l10n, failure),
        empty: EmptyState(
          icon: Icons.local_parking_outlined,
          title: l10n.facilitiesEmptyTitle,
          body: l10n.facilitiesEmptyBody,
        ),
        itemBuilder: (context, facility) {
          final (label, tone) = _status(l10n, facility);
          final reason = facility.rejectionReason;
          final spaces = facility.lot.pools.fold<int>(
            0,
            (sum, pool) => sum + pool.capacity,
          );

          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusChip(tone: tone, label: label),
                const Gap.sm(),
                Text(facility.lot.name, style: context.text.h3),
                const Gap.xs(),
                Text(
                  '${facility.lot.addressLine} · ${l10n.lotSpaces(spaces)}',
                  style: context.text.bodySmall.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                if (facility.approvalStatus == ApprovalStatus.rejected &&
                    reason != null &&
                    reason.isNotEmpty) ...[
                  const Gap.sm(),
                  Text(reason, style: context.text.bodySmall),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
