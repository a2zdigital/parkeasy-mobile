import 'package:app/core/api/api_exception.dart';
import 'package:app/core/state/cursor_list.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Draws a [CursorListState] with every state a list has: skeletons for
/// the first load, the empty state, the error state, the items, a spinner
/// while more load, and a retry row when more could not be loaded. Pull
/// to refresh is always available.
class CursorListView<T> extends StatelessWidget {
  const CursorListView({
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.itemBuilder,
    required this.empty,
    this.errorText,
    this.header,
    super.key,
  });

  final CursorListState<T> state;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget empty;

  /// The screen's own words for a failed first load, when it has them.
  final String? Function(ApiException failure)? errorText;

  /// Shown above the list in every state (filters, a summary), and
  /// scrolling with it.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final failure = state.failure;
    final loadMoreFailure = state.loadMoreFailure;
    final header = this.header;

    // The header scrolls with the content in every state, so a tall
    // header (a summary) never squeezes the list off a small screen.
    final lead = header == null ? 0 : 1;

    final Widget content;
    if (state.isLoading) {
      content = ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          ?header,
          for (var i = 0; i < 3; i++) ...[const Gap.md(), const SkeletonCard()],
        ],
      );
    } else if (failure != null) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ?header,
          ErrorState(
            failure: failure,
            message: errorText?.call(failure),
            onRetry: onRefresh,
          ),
        ],
      );
    } else if (state.isEmpty) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [?header, empty],
      );
    } else {
      content = NotificationListener<ScrollNotification>(
        onNotification: (scroll) {
          // Fetch the next page shortly before the end is reached.
          if (scroll.metrics.extentAfter < AppSize.touchTarget * 6 &&
              loadMoreFailure == null) {
            onLoadMore();
          }
          return false;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
          itemCount: lead + state.items.length + 1,
          separatorBuilder: (_, _) => const Gap.md(),
          itemBuilder: (context, index) {
            if (header != null && index == 0) return header;
            final itemIndex = index - lead;
            if (itemIndex < state.items.length) {
              return itemBuilder(context, state.items[itemIndex]);
            }
            if (state.isLoadingMore) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpace.lg),
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
                    l10n.describe(loadMoreFailure),
                    style: context.text.bodySmall.copyWith(
                      color: context.colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  TextAction(
                    label: l10n.actionTryAgain,
                    onPressed: state.hasMore ? onLoadMore : onRefresh,
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      );
    }

    return RefreshIndicator(onRefresh: onRefresh, child: content);
  }
}
