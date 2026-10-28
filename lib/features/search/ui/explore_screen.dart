import 'package:app/app/routes.dart';
import 'package:app/core/config/app_config.dart';
import 'package:app/core/providers.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_filter_chip.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/app_text_field.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/features/search/data/models/location_suggestion.dart';
import 'package:app/features/search/state/explore_notifier.dart';
import 'package:app/features/search/state/place_search_notifier.dart';
import 'package:app/features/search/ui/facility_card.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController();
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(exploreProvider);
    final notifier = ref.read(exploreProvider.notifier);
    final placeState = ref.watch(placeSearchProvider);
    final placeNotifier = ref.read(placeSearchProvider.notifier);
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
          title: state.vehicleType == null
              ? l10n.exploreEmptyTitle
              : l10n.exploreNoMatchingTitle,
          body: state.vehicleType == null
              ? l10n.exploreEmptyBody
              : l10n.exploreNoMatchingBody,
        ),
      );
    } else {
      results = _Results(state: state, notifier: notifier);
    }

    return AppScaffold(
      title: l10n.tabExplore,
      scrollable: false,
      body: Column(
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
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
                          l10n.exploreNear(state.origin.label),
                          style: context.text.bodySmall.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap.md(),
                  AppTextField(
                    label: l10n.exploreLocationLabel,
                    controller: _locationController,
                    hintText: l10n.exploreLocationHint,
                    helperText: l10n.exploreLocationHelper,
                    errorText: placeState.isInvalidQuery
                        ? l10n.exploreLocationRequired
                        : null,
                    prefixIcon: Icon(
                      Icons.search,
                      size: AppSize.iconSmall,
                      color: context.colors.textSecondary,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_locationController.text.isNotEmpty)
                          IconButton(
                            tooltip: l10n.exploreLocationClear,
                            onPressed: () {
                              _locationController.clear();
                              placeNotifier.updateQuery('');
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear),
                          ),
                        IconButton(
                          tooltip: l10n.exploreSearchLocation,
                          onPressed: placeState.isLoading
                              ? null
                              : () => placeNotifier.search(
                                  _locationController.text,
                                ),
                          icon: placeState.isLoading
                              ? SizedBox.square(
                                  dimension: AppSize.spinner,
                                  child: CircularProgressIndicator(
                                    strokeWidth: AppSize.focusBorderWidth,
                                    semanticsLabel:
                                        l10n.exploreSearchingLocations,
                                  ),
                                )
                              : const Icon(Icons.search),
                        ),
                      ],
                    ),
                    keyboardType: TextInputType.streetAddress,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.search,
                    onChanged: (query) {
                      placeNotifier.updateQuery(query);
                      setState(() {});
                    },
                    onSubmitted: placeNotifier.search,
                  ),
                  if (state.origin.latitude != config.searchOrigin.latitude ||
                      state.origin.longitude != config.searchOrigin.longitude)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextAction(
                        label: l10n.exploreUseDefaultLocation,
                        onPressed: () {
                          _locationController.clear();
                          placeNotifier.clear();
                          setState(() {});
                          notifier.useDefaultOrigin();
                        },
                      ),
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
                              onPressed: () =>
                                  notifier.selectVehicleType(type.code),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    const Gap.md(),
                ],
              ),
            ),
          ),
          Expanded(
            child: placeState.hasSearched
                ? _LocationSearchResults(
                    state: placeState,
                    onRetry: () => placeNotifier.search(placeState.query),
                    onSelected: (suggestion) {
                      _locationController.text = suggestion.name;
                      placeNotifier.clear();
                      setState(() {});
                      notifier.selectOrigin(
                        SearchOrigin(
                          latitude: suggestion.latitude,
                          longitude: suggestion.longitude,
                          label: suggestion.name,
                        ),
                      );
                    },
                  )
                : RefreshIndicator(onRefresh: notifier.load, child: results),
          ),
        ],
      ),
    );
  }
}

class _LocationSearchResults extends StatelessWidget {
  const _LocationSearchResults({
    required this.state,
    required this.onRetry,
    required this.onSelected,
  });

  final PlaceSearchState state;
  final VoidCallback onRetry;
  final ValueChanged<LocationSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (state.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: AppSize.focusBorderWidth,
          semanticsLabel: l10n.exploreSearchingLocations,
        ),
      );
    }

    final failure = state.failure;
    if (failure != null) {
      return SingleChildScrollView(
        child: ErrorState(failure: failure, onRetry: onRetry),
      );
    }

    if (state.isInvalidQuery) {
      return Center(child: Text(l10n.exploreLocationRequired));
    }

    if (state.suggestions.isEmpty) {
      return Center(
        child: Text(l10n.exploreLocationNoResults, textAlign: TextAlign.center),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: state.suggestions.length,
            separatorBuilder: (_, _) => const Gap.md(),
            itemBuilder: (context, index) {
              final suggestion = state.suggestions[index];
              return AppCard(
                onTap: () => onSelected(suggestion),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(suggestion.name, style: context.text.body),
                    const Gap.xs(),
                    Text(
                      suggestion.address,
                      style: context.text.bodySmall.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
          child: Text(
            l10n.exploreGoogleMapsAttribution,
            style: context.text.bodySmall.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
      ],
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
