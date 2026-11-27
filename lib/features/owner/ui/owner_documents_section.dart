import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/files/picked_file.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/features/owner/data/models/owner_document.dart';
import 'package:app/features/owner/state/owner_documents_notifier.dart';
import 'package:app/features/owner/ui/identity_cards_section.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The documents an applicant sends with their owner application: their
/// Aadhaar card and PAN card, each with its number, checked as it is typed.
/// They can be removed until the application is approved.
class OwnerDocumentsSection extends ConsumerWidget {
  const OwnerDocumentsSection({
    required this.canRemove,
    this.showTitle = true,
    this.onCardsComplete,
    super.key,
  });

  /// Cards can always be added; removing stops once the owner is approved
  /// (the API keeps them as the verification record).
  final bool canRemove;
  final bool showTitle;

  /// Called once the owner has just saved the second of the two cards.
  final VoidCallback? onCardsComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final documents = ref.watch(ownerDocumentsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) SectionHeader(l10n.documentsTitle),
        documents.when(
          loading: () => const SkeletonCard(),
          error: (error, _) => ErrorState(
            failure: error is ApiException
                ? error
                : const ApiException(code: ApiErrorCode.unknown),
            onRetry: () => ref.invalidate(ownerDocumentsProvider),
          ),
          data: (state) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.problem case final problem?) ...[
                AppBanner(
                  tone: StatusTone.danger,
                  message: pickProblemText(l10n, problem),
                ),
                const Gap.sm(),
              ],
              if (state.failure case final failure?) ...[
                AppBanner(
                  tone: StatusTone.danger,
                  message: l10n.describe(failure),
                ),
                const Gap.sm(),
              ],
              IdentityCardsSection(
                canRemove: canRemove,
                onComplete: onCardsComplete,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A calendar date as YYYY-MM-DD, as the API expects.
String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// What to tell the owner when a chosen file could not be used.
String pickProblemText(
  AppLocalizations l10n,
  PickProblem problem, {
  bool photo = false,
}) => switch (problem) {
  PickProblem.tooLarge => l10n.uploadTooLarge,
  PickProblem.wrongType => photo ? l10n.photoWrongType : l10n.documentWrongType,
  PickProblem.unreadable => l10n.pickUnreadable,
};

/// A line under a document whose malware scan has not passed, or null when
/// it has. A failed scan is retried by the server, so it reads as pending.
String? scanNote(AppLocalizations l10n, DocumentScanStatus status) =>
    switch (status) {
      DocumentScanStatus.clean || DocumentScanStatus.unknown => null,
      DocumentScanStatus.pending ||
      DocumentScanStatus.failed => l10n.documentScanPending,
      DocumentScanStatus.infected => l10n.documentScanInfected,
    };
