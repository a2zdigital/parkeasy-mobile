import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/features/owner/data/models/verification_status.dart';
import 'package:app/features/owner/state/owner_application_notifier.dart';
import 'package:app/features/owner/ui/identity_cards_section.dart';
import 'package:app/features/owner/ui/owner_documents_section.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Profile > Documents: the owner's Aadhaar and PAN cards. Once the owner is
/// approved, cards can be added but not removed (the API keeps them as the
/// verification record).
class OwnerDocumentsScreen extends ConsumerWidget {
  const OwnerDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final application = ref
        .watch(ownerApplicationProvider)
        .valueOrNull
        ?.application;
    final approved =
        application?.verificationStatus == VerificationStatus.approved;

    return AppScaffold(
      title: context.l10n.documentsTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap.md(),
          OwnerDocumentsSection(
            canRemove: !approved,
            showTitle: false,
            onCardsComplete: () =>
                goHomeAfterIdentityCards(context, ref, ownerArea: approved),
          ),
          const Gap.xl(),
        ],
      ),
    );
  }
}
