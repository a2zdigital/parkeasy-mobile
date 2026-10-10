import 'package:app/app/routes.dart';
import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/app_text_field.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/features/auth/state/phone_number.dart';
import 'package:app/features/owner/data/models/parking_owner.dart';
import 'package:app/features/owner/data/models/verification_status.dart';
import 'package:app/features/owner/state/owner_application_notifier.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The way into the owner area: apply, see where the application stands,
/// and enter once it is approved.
class OwnerApplicationScreen extends ConsumerStatefulWidget {
  const OwnerApplicationScreen({super.key});

  @override
  ConsumerState<OwnerApplicationScreen> createState() =>
      _OwnerApplicationScreenState();
}

class _OwnerApplicationScreenState
    extends ConsumerState<OwnerApplicationScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() => ref
      .read(ownerApplicationProvider.notifier)
      .apply(businessName: _name.text, contactPhone: _phone.text);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final application = ref.watch(ownerApplicationProvider);

    return application.when(
      loading: () => AppScaffold(
        title: l10n.profileOwnerArea,
        body: const Column(children: [Gap.lg(), SkeletonCard()]),
      ),
      error: (error, _) => AppScaffold(
        title: l10n.profileOwnerArea,
        body: Center(
          child: ErrorState(
            failure: error is ApiException
                ? error
                : const ApiException(code: ApiErrorCode.unknown),
            onRetry: () => ref.invalidate(ownerApplicationProvider),
          ),
        ),
      ),
      data: (state) {
        final existing = state.application;
        if (existing != null) return _Status(application: existing);

        final failure = state.failure;
        void clear(String _) =>
            ref.read(ownerApplicationProvider.notifier).clearProblems();

        return AppScaffold(
          title: l10n.ownerApplyTitle,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap.md(),
              Text(
                l10n.ownerApplyBody,
                style: context.text.body.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              const Gap.xl(),
              AppTextField(
                label: l10n.ownerBusinessName,
                controller: _name,
                enabled: !state.isSubmitting,
                errorText: state.isNameMissing
                    ? l10n.ownerBusinessNameRequired
                    : null,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onChanged: clear,
              ),
              const Gap.sm(),
              AppTextField(
                label: l10n.ownerContactPhone,
                controller: _phone,
                enabled: !state.isSubmitting,
                prefixText: '${PhoneNumber.countryCode} ',
                helperText: l10n.phoneHelper,
                errorText: state.isPhoneInvalid ? l10n.phoneInvalid : null,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(PhoneNumber.nationalLength),
                ],
                onChanged: clear,
                onSubmitted: (_) => _submit(),
              ),
              if (failure != null) ...[
                const Gap.sm(),
                AppBanner(
                  tone: StatusTone.danger,
                  message: l10n.describe(failure),
                ),
              ],
            ],
          ),
          bottom: PrimaryButton(
            label: l10n.ownerApplySubmit,
            isLoading: state.isSubmitting,
            onPressed: _submit,
          ),
        );
      },
    );
  }
}

class _Status extends ConsumerWidget {
  const _Status({required this.application});

  final ParkingOwner application;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final reason = application.rejectionReason;

    final (
      IconData icon,
      Color color,
      String title,
      String body,
    ) = switch (application.verificationStatus) {
      VerificationStatus.approved => (
        Icons.verified_outlined,
        colors.success.solid,
        l10n.ownerApprovedTitle,
        l10n.ownerApprovedBody(application.businessName),
      ),
      VerificationStatus.rejected => (
        Icons.block_outlined,
        colors.danger.solid,
        l10n.ownerRejectedTitle,
        reason == null || reason.isEmpty
            ? l10n.ownerRejectedBody
            : '$reason ${l10n.ownerRejectedBody}',
      ),
      VerificationStatus.pending || VerificationStatus.unknown => (
        Icons.hourglass_empty_outlined,
        colors.warning.solid,
        l10n.ownerPendingTitle,
        l10n.ownerPendingBody(application.businessName),
      ),
    };
    final isApproved =
        application.verificationStatus == VerificationStatus.approved;

    return AppScaffold(
      title: l10n.profileOwnerArea,
      scrollable: false,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(ownerApplicationProvider),
        child: ListView(
          children: [
            const Gap.xxl(),
            ExcludeSemantics(
              child: Icon(icon, size: AppSize.touchTarget, color: color),
            ),
            const Gap.lg(),
            Text(title, style: context.text.h2, textAlign: TextAlign.center),
            const Gap.sm(),
            Text(
              body,
              style: context.text.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      bottom: isApproved
          ? PrimaryButton(
              label: l10n.ownerOpen,
              onPressed: () => context.go(Routes.ownerBookings),
            )
          : null,
    );
  }
}
