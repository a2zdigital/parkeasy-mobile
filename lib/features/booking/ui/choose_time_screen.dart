import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/time/facility_time.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_filter_chip.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/core/widgets/status_chip.dart';
import 'package:app/features/booking/state/choose_time_notifier.dart';
import 'package:app/features/booking/ui/price_breakdown.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChooseTimeScreen extends ConsumerWidget {
  const ChooseTimeScreen({required this.lotId, super.key});

  final String lotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(chooseTimeProvider(lotId));

    return state.when(
      loading: () => AppScaffold(
        title: l10n.timeTitle,
        body: const Column(
          children: [Gap.lg(), SkeletonCard(), Gap.md(), SkeletonCard()],
        ),
      ),
      error: (error, _) => AppScaffold(
        title: l10n.timeTitle,
        body: Center(
          child: ErrorState(
            failure: error is ApiException
                ? error
                : const ApiException(code: ApiErrorCode.unknown),
            onRetry: () => ref.invalidate(chooseTimeProvider(lotId)),
          ),
        ),
      ),
      data: (state) => AppScaffold(
        title: l10n.timeTitle,
        body: _Form(
          state: state,
          notifier: ref.read(chooseTimeProvider(lotId).notifier),
        ),
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.state, required this.notifier});

  final ChooseTimeState state;
  final ChooseTimeNotifier notifier;

  /// Opens the date picker, then the time picker, working in the
  /// facility's clock, and returns the chosen instant in UTC.
  Future<DateTime?> _pick(BuildContext context, DateTime current) async {
    final zone = state.lot.timezone;
    final wall = FacilityTime.toWall(current, zone);
    final today = FacilityTime.toWall(DateTime.now(), zone);

    final date = await showDatePicker(
      context: context,
      initialDate: wall,
      firstDate: DateTime.utc(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 90)),
    );
    if (date == null || !context.mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: wall.hour, minute: wall.minute),
    );
    if (time == null) return null;

    return FacilityTime.fromWall(
      DateTime.utc(date.year, date.month, date.day, time.hour, time.minute),
      zone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final lot = state.lot;
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap.md(),
        Text(lot.name, style: text.h3),
        if (lot.pools.length > 1) ...[
          const Gap.lg(),
          Text(
            l10n.timeVehicle,
            style: text.label.copyWith(color: colors.textSecondary),
          ),
          Wrap(
            spacing: AppSpace.sm,
            children: [
              for (final pool in lot.pools)
                AppFilterChip(
                  label: pool.vehicleType.name,
                  isSelected: state.vehicleType == pool.vehicleType.code,
                  onPressed: () =>
                      notifier.setVehicleType(pool.vehicleType.code),
                ),
            ],
          ),
        ],
        const Gap.lg(),
        _TimeRow(
          label: l10n.timeArrive,
          value: FacilityTime.dayAndTime(state.startAt, lot.timezone, locale),
          onTap: () async {
            final picked = await _pick(context, state.startAt);
            if (picked != null) notifier.setStart(picked);
          },
        ),
        const Gap.md(),
        _TimeRow(
          label: l10n.timeLeave,
          value: FacilityTime.dayAndTime(state.endAt, lot.timezone, locale),
          onTap: () async {
            final picked = await _pick(context, state.endAt);
            if (picked != null) notifier.setEnd(picked);
          },
        ),
        const Gap.sm(),
        Text(
          l10n.timeZoneNote(FacilityTime.label(lot.timezone)),
          style: text.label.copyWith(color: colors.textSecondary),
        ),
        const Gap.xl(),
        _PricingView(pricing: state.pricing, onRetry: notifier.retry),
        const Gap.xl(),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;

    return Semantics(
      button: true,
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: text.label.copyWith(color: colors.textSecondary),
                  ),
                  const Gap.xs(),
                  Text(value, style: text.body),
                ],
              ),
            ),
            ExcludeSemantics(
              child: Icon(
                Icons.edit_calendar_outlined,
                size: AppSize.icon,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PricingView extends StatelessWidget {
  const _PricingView({required this.pricing, required this.onRetry});

  final Pricing pricing;
  final VoidCallback onRetry;

  /// The reasons a window cannot be booked, in the app's words. Anything
  /// else is a failure to reach the API and offers a retry.
  static String? _reason(AppLocalizations l10n, ApiException failure) =>
      switch (failure.code) {
        ApiErrorCode.outsideOperatingHours => l10n.errOutsideHours,
        ApiErrorCode.invalidBookingWindow ||
        ApiErrorCode.validationFailed => l10n.errInvalidWindow,
        ApiErrorCode.vehicleTypeNotSupported => l10n.errVehicleNotSupported,
        ApiErrorCode.parkingLotNotBookable ||
        ApiErrorCode.notFound => l10n.errNotBookable,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    switch (pricing) {
      case PricingLoading():
        return Semantics(label: l10n.timeChecking, child: const SkeletonCard());

      case PricingFailed(:final failure):
        final reason = _reason(l10n, failure);
        if (reason != null) {
          return AppBanner(tone: StatusTone.warning, message: reason);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBanner(tone: StatusTone.danger, message: l10n.describe(failure)),
            const Gap.sm(),
            SecondaryButton(label: l10n.actionTryAgain, onPressed: onRetry),
          ],
        );

      case Priced(:final quote, :final availability):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: availability.isAvailable
                  ? StatusChip(
                      tone: StatusTone.available,
                      icon: Icons.local_parking_outlined,
                      label:
                          '${l10n.timeAvailable} · ${l10n.timeSpacesLeft(availability.spacesLeft)}',
                    )
                  : StatusChip(
                      tone: StatusTone.danger,
                      icon: Icons.block_outlined,
                      label: l10n.timeFull,
                    ),
            ),
            const Gap.md(),
            PriceBreakdown(lines: quote.lines, total: quote.total),
            const Gap.md(),
            AppBanner(tone: StatusTone.info, message: l10n.timeNextBuild),
          ],
        );
    }
  }
}
