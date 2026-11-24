import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/files/picked_file.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/confirm_dialog.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/features/owner/data/models/owner_document.dart';
import 'package:app/features/owner/state/owner_documents_notifier.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The documents an applicant sends with their owner application: identity,
/// business and property proof. All optional: none is needed to apply or to
/// list a facility. They can be removed until the application is approved.
class OwnerDocumentsSection extends ConsumerWidget {
  const OwnerDocumentsSection({
    required this.canRemove,
    this.showTitle = true,
    super.key,
  });

  /// Documents can always be added; removing stops once the owner is
  /// approved (the API keeps them as the verification record).
  final bool canRemove;
  final bool showTitle;

  static const _extensions = ['pdf', 'jpg', 'jpeg', 'png'];

  static String typeLabel(AppLocalizations l10n, OwnerDocumentType type) =>
      switch (type) {
        OwnerDocumentType.identity => l10n.documentTypeIdentity,
        OwnerDocumentType.business => l10n.documentTypeBusiness,
        OwnerDocumentType.property => l10n.documentTypeProperty,
        OwnerDocumentType.licence => l10n.documentTypeLicence,
        OwnerDocumentType.unknown => type.wire,
      };

  static String size(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).ceil()} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final type = await showModalBottomSheet<OwnerDocumentType>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Text(l10n.documentChooseType, style: context.text.h3),
              ),
              for (final type in const [
                OwnerDocumentType.identity,
                OwnerDocumentType.business,
                OwnerDocumentType.property,
                OwnerDocumentType.licence,
              ])
                ListTile(
                  title: Text(typeLabel(l10n, type)),
                  onTap: () => Navigator.of(context).pop(type),
                ),
              const Gap.md(),
            ],
          ),
        ),
      ),
    );
    if (type == null || !context.mounted) return;

    String? parkingLotId;
    if (type == OwnerDocumentType.licence) {
      final selection = await showModalBottomSheet<_FacilitySelection>(
        context: context,
        isScrollControlled: true,
        builder: (context) => const _FacilityPickerSheet(),
      );
      if (selection == null || !context.mounted) return;
      parkingLotId = selection.parkingLotId;
    }

    final PickedFile? file;
    try {
      file = await ref
          .read(filePickerServiceProvider)
          .pick(extensions: _extensions);
    } on PickException catch (error) {
      ref.read(ownerDocumentsProvider.notifier).pickFailed(error.problem);
      return;
    }
    if (file == null || !context.mounted) return;

    // Optional: with an expiry date the owner is reminded before it runs
    // out. Not asked for a file that will be refused anyway.
    final now = DateTime.now();
    final expires = file.sizeBytes > maxUploadBytes
        ? null
        : await showDatePicker(
            context: context,
            helpText: l10n.documentExpiryPrompt,
            cancelText: l10n.documentExpirySkip,
            firstDate: DateTime(now.year, now.month, now.day),
            lastDate: DateTime(now.year + 30),
          );

    await ref
        .read(ownerDocumentsProvider.notifier)
        .upload(
          type,
          file,
          expiresOn: expires == null ? null : isoDate(expires),
          parkingLotId: parkingLotId,
        );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    OwnerDocument document,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.documentRemoveTitle,
      body: l10n.documentRemoveBody(document.fileName),
      confirmLabel: l10n.documentRemove,
      cancelLabel: l10n.actionCancel,
      isDestructive: true,
    );
    if (confirmed) {
      await ref.read(ownerDocumentsProvider.notifier).remove(document);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final documents = ref.watch(ownerDocumentsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) SectionHeader(l10n.documentsTitle),
        Text(
          canRemove ? l10n.documentsHint : l10n.documentsApprovedHint,
          style: text.bodySmall.copyWith(color: colors.textSecondary),
        ),
        const Gap.md(),
        documents.when(
          loading: () => const SkeletonCard(),
          error: (error, _) => ErrorState(
            failure: error is ApiException
                ? error
                : const ApiException(code: ApiErrorCode.unknown),
            onRetry: () => ref.invalidate(ownerDocumentsProvider),
          ),
          data: (state) {
            final failure = state.failure;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.problem case final problem?)
                  AppBanner(
                    tone: StatusTone.danger,
                    message: pickProblemText(l10n, problem),
                  ),
                if (failure != null)
                  AppBanner(
                    tone: StatusTone.danger,
                    message: l10n.describe(failure),
                  ),
                if (state.problem != null || failure != null) const Gap.sm(),
                if (state.documents.isEmpty)
                  Text(
                    l10n.documentsEmpty,
                    style: text.body.copyWith(color: colors.textSecondary),
                  ),
                for (final (index, document) in state.documents.indexed) ...[
                  if (index > 0) const Gap.sm(),
                  AppCard(
                    child: Row(
                      children: [
                        Icon(
                          document.mimeType == 'application/pdf'
                              ? Icons.picture_as_pdf_outlined
                              : Icons.image_outlined,
                          color: colors.textSecondary,
                        ),
                        const Gap.md(),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                typeLabel(l10n, document.type),
                                style: text.body,
                              ),
                              if (scanNote(l10n, document.scanStatus)
                                  case final note?)
                                Text(
                                  note,
                                  style: text.bodySmall.copyWith(
                                    color:
                                        document.scanStatus ==
                                            DocumentScanStatus.infected
                                        ? colors.danger.solid
                                        : colors.textSecondary,
                                  ),
                                ),
                              if (document.expiresOn case final expires?)
                                Text(
                                  document.isExpired
                                      ? l10n.documentExpired(expires)
                                      : l10n.documentExpires(expires),
                                  style: text.bodySmall.copyWith(
                                    color: document.isExpired
                                        ? colors.danger.solid
                                        : colors.textSecondary,
                                  ),
                                ),
                              if (document.parkingLotName
                                  case final facilityName?)
                                Text(
                                  l10n.documentLinkedFacility(facilityName),
                                  style: text.bodySmall.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              Text(
                                '${document.fileName} · ${size(document.sizeBytes)}',
                                style: text.bodySmall.copyWith(
                                  color: colors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (canRemove)
                          IconButton(
                            tooltip: l10n.documentRemove,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: state.isBusy
                                ? null
                                : () => _remove(context, ref, document),
                          ),
                      ],
                    ),
                  ),
                ],
                ...[
                  const Gap.md(),
                  SecondaryButton(
                    label: l10n.documentAdd,
                    isLoading: state.isBusy,
                    onPressed: () => _add(context, ref),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FacilitySelection {
  const _FacilitySelection(this.parkingLotId);

  final String? parkingLotId;
}

class _FacilityPickerSheet extends ConsumerWidget {
  const _FacilityPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final facilities = ref.watch(ownerFacilityChoicesProvider);

    return SafeArea(
      child: facilities.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpace.lg),
          child: SkeletonCard(),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ErrorState(
                failure: error is ApiException
                    ? error
                    : const ApiException(code: ApiErrorCode.unknown),
                onRetry: () => ref.invalidate(ownerFacilityChoicesProvider),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(const _FacilitySelection(null)),
                child: Text(l10n.documentContinueWithoutFacility),
              ),
            ],
          ),
        ),
        data: (items) => SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.documentChooseFacility, style: context.text.h3),
                const Gap.sm(),
                ListTile(
                  title: Text(l10n.documentNoFacilityLink),
                  onTap: () =>
                      Navigator.of(context).pop(const _FacilitySelection(null)),
                ),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                    child: Text(
                      l10n.documentNoFacilities,
                      style: context.text.bodySmall.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                for (final facility in items)
                  ListTile(
                    title: Text(facility.lot.name),
                    subtitle: Text(
                      '${facility.lot.city}, ${facility.lot.state}',
                    ),
                    onTap: () => Navigator.of(
                      context,
                    ).pop(_FacilitySelection(facility.lot.id)),
                  ),
              ],
            ),
          ),
        ),
      ),
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
@visibleForTesting
String? scanNote(AppLocalizations l10n, DocumentScanStatus status) =>
    switch (status) {
      DocumentScanStatus.clean || DocumentScanStatus.unknown => null,
      DocumentScanStatus.pending ||
      DocumentScanStatus.failed => l10n.documentScanPending,
      DocumentScanStatus.infected => l10n.documentScanInfected,
    };
