import 'package:app/app/routes.dart';
import 'package:app/core/providers.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_filter_chip.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/features/search/state/explore_notifier.dart';
import 'package:app/features/search/ui/facility_card.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(exploreProvider);
    final notifier = ref.read(exploreProvider.notifier);
    final config = ref.watch(appConfigProvider);
    final failure = state.failure;

    final Widget results;
    if (state.isLoading) {
      results = const _Loading();
    } else if (failure != null) {
      results = SingleChildScrollView(
        child: ErrorState(failure: failure, onRetry: notifier.load),
      );
    } else if (state.isEmpty) {
      results = SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: EmptyState(
          icon: Icons.local_parking_outlined,
          title: l10n.exploreEmptyTitle,
          body: l10n.exploreEmptyBody(config.searchRadiusKm.round()),
        ),
      );
    } else {
      results = _Results(state: state, notifier: notifier);
    }

    return AppScaffold(
      title: l10n.tabExplore,
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap.md(),
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.place_outlined,
                  size: AppSize.iconSmall,
                  color: context.colors.textSecondary,
                ),
              ),
              const Gap.xs(),
              Expanded(
                child: Text(
                  l10n.exploreNear(config.searchOrigin.label),
                  style: context.text.bodySmall.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (state.vehicleTypes.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  AppFilterChip(
                    label: l10n.exploreAllVehicles,
                    isSelected: state.vehicleType == null,
                    onPressed: () => notifier.selectVehicleType(null),
                  ),
                  for (final type in state.vehicleTypes) ...[
                    const Gap.sm(),
                    AppFilterChip(
                      label: type.name,
                      isSelected: state.vehicleType == type.code,
                      onPressed: () => notifier.selectVehicleType(type.code),
                    ),
                  ],
                ],
              ),
            )
          else
            const Gap.md(),
          Expanded(
            child: RefreshIndicator(onRefresh: notifier.load, child: results),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => ListView.separated(
    physics: const NeverScrollableScrollPhysics(),
    itemCount: 4,
    separatorBuilder: (_, _) => const Gap.md(),
    itemBuilder: (_, _) => const SkeletonCard(),
  );
}

class _Results extends StatelessWidget {
  const _Results({required this.state, required this.notifier});

  final ExploreState state;
  final ExploreNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final loadMoreFailure = state.loadMoreFailure;

    return NotificationListener<ScrollNotification>(
      onNotification: (scroll) {
        // Fetch the next page shortly before the end is reached.
        if (scroll.metrics.extentAfter < AppSize.touchTarget * 6 &&
            loadMoreFailure == null) {
          notifier.loadMore();
        }
        return false;
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpace.xl),
        itemCount: state.items.length + 1,
        separatorBuilder: (_, _) => const Gap.md(),
        itemBuilder: (context, index) {
          if (index < state.items.length) {
            final lot = state.items[index];
            return FacilityCard(
              lot: lot,
              onTap: () => context.push(Routes.parkingLot(lot.id)),
            );
          }

          if (state.isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.all(AppSpace.lg),
              child: Center(
                child: SizedBox.square(
                  dimension: AppSize.spinner,
                  child: CircularProgressIndicator(
                    strokeWidth: AppSize.focusBorderWidth,
                  ),
                ),
              ),
            );
          }
          if (loadMoreFailure != null) {
            return Column(
              children: [
                Text(
                  '${l10n.exploreLoadMoreFailed} ${l10n.describe(loadMoreFailure)}',
                  style: context.text.bodySmall.copyWith(
                    color: context.colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                TextAction(
                  label: l10n.actionTryAgain,
                  onPressed: state.hasMore ? notifier.loadMore : notifier.load,
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
