import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/money/money.dart';
import 'package:app/core/money/money_format.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/time/facility_time.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/cursor_list_view.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/features/owner/data/models/earning_entry.dart';
import 'package:app/features/owner/data/models/earning_kind.dart';
import 'package:app/features/owner/data/models/owner_earnings.dart';
import 'package:app/features/owner/state/owner_lists.dart';
import 'package:app/features/owner/ui/owner_common.dart';
import 'package:app/l10n/l10n.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The owner's money position, exactly as the API reports it. The app
/// adds nothing up.
class OwnerEarningsScreen extends ConsumerWidget {
  const OwnerEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summary = ref.watch(ownerEarningsProvider);
    final entries = ref.watch(ownerEarningEntriesProvider);
    final notifier = ref.read(ownerEarningEntriesProvider.notifier);
    final locale = Localizations.localeOf(context).toLanguageTag();

    final Widget header = summary.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: AppSpace.md),
        child: SkeletonCard(),
      ),
      error: (error, _) {
        final failure = error is ApiException
            ? error
            : const ApiException(code: ApiErrorCode.unknown);
        return ErrorState(
          failure: failure,
          message: ownerAccessText(l10n, failure),
          onRetry: () => ref.invalidate(ownerEarningsProvider),
        );
      },
      data: (earnings) => _Summary(earnings: earnings),
    );

    return AppScaffold(
      title: l10n.ownerTabEarnings,
      actions: const [ExitOwnerAreaAction()],
      scrollable: false,
      body: CursorListView<EarningEntry>(
        state: entries,
        onRefresh: () async {
          ref.invalidate(ownerEarningsProvider);
          await notifier.load();
        },
        onLoadMore: notifier.loadMore,
        // The summary above already explains an access problem.
        errorText: (failure) => ownerAccessText(l10n, failure),
        header: summary.hasError
            ? header
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [header, SectionHeader(l10n.earningsEntries)],
              ),
        empty: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
          child: Text(
            l10n.earningsEntriesEmpty,
            style: context.text.body.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
        itemBuilder: (context, entry) =>
            _EntryCard(entry: entry, locale: locale),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.earnings});

  final OwnerEarnings earnings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String money(Decimal amount) =>
        formatMoney(Money(amount, earnings.currency));

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.md),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Tile(
                  label: l10n.earningsPayable,
                  value: formatMoney(earnings.payable),
                  hint: l10n.earningsPayableHint,
                ),
              ),
              const Gap.md(),
              Expanded(
                child: _Tile(
                  label: l10n.earningsOwed,
                  value: formatMoney(earnings.owed),
                  hint: l10n.earningsOwedHint,
                ),
              ),
            ],
          ),
          const Gap.md(),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.earningsOnline, style: context.text.h3),
                const Gap.sm(),
                _Line(l10n.earningsCollected, money(earnings.online.collected)),
                _Line(
                  l10n.earningsCommission,
                  money(earnings.online.commission),
                ),
                _Line(l10n.earningsRefunded, money(earnings.online.refunded)),
                _Line(l10n.earningsEarned, money(earnings.online.earned)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpace.md),
                  child: Divider(),
                ),
                Text(l10n.earningsOnSite, style: context.text.h3),
                const Gap.sm(),
                _Line(l10n.earningsCollected, money(earnings.onSite.collected)),
                _Line(
                  l10n.earningsCommission,
                  money(earnings.onSite.commission),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.hint});

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.text.label.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const Gap.xs(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: context.text.h2),
          ),
          const Gap.xs(),
          Text(
            hint,
            style: context.text.label.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
    child: MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.text.bodySmall.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: context.text.bodySmall.copyWith(
              fontFeatures: context.text.price.fontFeatures,
            ),
          ),
        ],
      ),
    ),
  );
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.locale});

  final EarningEntry entry;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;

    // What matters about an entry depends on its kind: the owner's share
    // for online bookings, the commission they owe for on-site ones.
    final (String kind, Decimal amount) = switch (entry.kind) {
      EarningKind.earned => (l10n.entryEarned, entry.ownerAmount),
      EarningKind.reversed => (l10n.entryReversed, entry.ownerAmount),
      EarningKind.owedOnsite => (l10n.entryOwedOnsite, entry.commissionAmount),
      EarningKind.unknown => (entry.kind.wire, entry.ownerAmount),
    };

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kind, style: text.body),
                const Gap.xs(),
                Text(
                  '${l10n.entryRate(entry.commissionRate.toString())} · '
                  // Entries have no facility, so the pilot's zone is used.
                  '${FacilityTime.dayAndTime(entry.createdAt, 'Asia/Kolkata', locale)}',
                  style: text.bodySmall.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const Gap.md(),
          Text(formatMoney(Money(amount, entry.currency)), style: text.price),
        ],
      ),
    );
  }
}
