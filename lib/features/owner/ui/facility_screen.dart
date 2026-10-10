import 'package:app/app/routes.dart';
import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/money/money_format.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/time/facility_time.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/features/owner/data/models/approval_status.dart';
import 'package:app/features/owner/data/models/owner_parking_lot.dart';
import 'package:app/features/owner/state/owner_facility_notifier.dart';
import 'package:app/features/owner/ui/facility_form_screen.dart';
import 'package:app/features/owner/ui/owner_common.dart';
import 'package:app/features/parking_lot/data/models/rate_type.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// One facility: where it stands in review, and the three things that
/// make it bookable: details, spaces with rates, and opening hours.
class FacilityScreen extends ConsumerWidget {
  const FacilityScreen({required this.id, super.key});

  final String id;

  static (StatusTone, String) _note(
    AppLocalizations l10n,
    OwnerParkingLot facility,
  ) {
    final reason = facility.rejectionReason;
    return switch (facility.approvalStatus) {
      ApprovalStatus.approved => (StatusTone.success, l10n.facilityLiveNote),
      ApprovalStatus.pending => (StatusTone.warning, l10n.facilityPendingNote),
      ApprovalStatus.rejected => (
        StatusTone.danger,
        reason == null || reason.isEmpty
            ? l10n.facilityRejectedNoReason
            : l10n.facilityRejectedNote(reason),
      ),
      ApprovalStatus.draft ||
      ApprovalStatus.unknown => (StatusTone.info, l10n.facilityDraftNote),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = ownerFacilityProvider(id);
    final details = ref.watch(provider);

    return details.when(
      loading: () => AppScaffold(
        title: l10n.ownerTabFacilities,
        body: const Column(
          children: [Gap.lg(), SkeletonCard(), Gap.md(), SkeletonCard()],
        ),
      ),
      error: (error, _) {
        final failure = error is ApiException
            ? error
            : const ApiException(code: ApiErrorCode.unknown);
        return AppScaffold(
          title: l10n.ownerTabFacilities,
          body: Center(
            child: ErrorState(
              failure: failure,
              message: ownerAccessText(l10n, failure),
              onRetry: () => ref.invalidate(provider),
            ),
          ),
        );
      },
      data: (state) {
        final facility = state.facility;
        final lot = facility.lot;
        final text = context.text;
        final colors = context.colors;
        final locale = Localizations.localeOf(context).toLanguageTag();
        final failure = state.failure;
        final (tone, note) = _note(l10n, facility);
        final hours = [...lot.operatingHours]
          ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

        String describeDay(int index) {
          final day = hours[index];
          final opens = day.opensAt;
          final closes = day.closesAt;
          if (day.isClosed || opens == null || closes == null) {
            return l10n.lotClosed;
          }
          if (opens.startsWith('00:00') && closes.startsWith('24:00')) {
            return l10n.lotOpen24;
          }
          return l10n.lotHoursRange(
            FacilityTime.clock(opens, locale),
            FacilityTime.clock(closes, locale),
          );
        }

        return AppScaffold(
          title: lot.name,
          scrollable: false,
          bottom: state.canSubmit
              ? PrimaryButton(
                  label: l10n.facilitySubmit,
                  isLoading: state.isBusy,
                  onPressed: ref.read(provider.notifier).submit,
                )
              : null,
          // The status and any refusal stay in view while the sections
          // below scroll, so the result of "Submit" is never off screen.
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Gap.md(),
              AppBanner(
                tone: state.justSubmitted ? StatusTone.success : tone,
                message: state.justSubmitted ? l10n.facilitySubmitted : note,
              ),
              if (failure != null) ...[
                const Gap.sm(),
                AppBanner(
                  tone: StatusTone.danger,
                  message: facilityFailureText(l10n, failure),
                ),
              ],
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => ref.invalidate(provider),
                  child: ListView(
                    children: [
                      _Section(
                        title: l10n.facilityDetails,
                        action: state.canEdit ? l10n.facilityEdit : null,
                        onAction: () =>
                            context.push(Routes.ownerFacilityEdit(id)),
                      ),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${lot.addressLine}, ${lot.city} ${lot.postalCode}',
                              style: text.body,
                            ),
                            const Gap.xs(),
                            Text(
                              lot.amenities.map((a) => a.name).join(' · '),
                              style: text.bodySmall.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _Section(
                        title: l10n.facilitySpaces,
                        action: state.canEdit ? l10n.facilityAddVehicle : null,
                        onAction: () =>
                            context.push(Routes.ownerFacilityPool(id)),
                      ),
                      if (lot.pools.isEmpty)
                        Text(
                          l10n.facilityNoSpaces,
                          style: text.body.copyWith(
                            color: colors.textSecondary,
                          ),
                        )
                      else
                        for (final (index, pool) in lot.pools.indexed) ...[
                          if (index > 0) const Gap.md(),
                          Semantics(
                            button: state.canEdit,
                            child: AppCard(
                              onTap: state.canEdit
                                  ? () => context.push(
                                      Routes.ownerFacilityPool(
                                        id,
                                        poolId: pool.id,
                                      ),
                                    )
                                  : null,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          pool.vehicleType.name,
                                          style: text.h3,
                                        ),
                                      ),
                                      Text(
                                        l10n.lotSpaces(pool.capacity),
                                        style: text.bodySmall.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  for (final rate in pool.rates) ...[
                                    const Gap.xs(),
                                    Text(switch (rate.rateType) {
                                      RateType.hourly => l10n.pricePerHour(
                                        formatMoney(rate.price),
                                      ),
                                      RateType.daily => l10n.pricePerDay(
                                        formatMoney(rate.price),
                                      ),
                                      RateType.unknown => formatMoney(
                                        rate.price,
                                      ),
                                    }, style: text.bodySmall),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      _Section(
                        title: l10n.lotHours,
                        action: state.canEdit ? l10n.facilityEdit : null,
                        onAction: () =>
                            context.push(Routes.ownerFacilityHours(id)),
                      ),
                      if (hours.isEmpty)
                        Text(
                          l10n.facilityNoHours,
                          style: text.body.copyWith(
                            color: colors.textSecondary,
                          ),
                        )
                      else
                        AppCard(
                          child: Column(
                            children: [
                              for (var i = 0; i < hours.length; i++) ...[
                                if (i > 0) const Gap.sm(),
                                MergeSemantics(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          FacilityTime.weekday(
                                            hours[i].dayOfWeek,
                                            locale,
                                          ),
                                          style: text.bodySmall,
                                        ),
                                      ),
                                      Text(
                                        describeDay(i),
                                        style: text.bodySmall.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      const Gap.xl(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final action = this.action;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: SectionHeader(title)),
        if (action != null) TextAction(label: action, onPressed: onAction),
      ],
    );
  }
}
