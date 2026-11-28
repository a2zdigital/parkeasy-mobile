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
import 'package:app/features/owner/data/models/gst_registration.dart';
import 'package:app/features/owner/data/owner_repository.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The owner's GST registrations, newest first.
final ownerGstRegistrationsProvider =
    FutureProvider.autoDispose<List<GstRegistration>>(
      (ref) => ref.watch(ownerRepositoryProvider).gstRegistrations(),
    );

/// An owner adds a GSTIN for each state they have facilities in. The platform
/// checks it; once verified, GST is added to bookings at those facilities.
class OwnerGstScreen extends ConsumerStatefulWidget {
  const OwnerGstScreen({super.key});

  @override
  ConsumerState<OwnerGstScreen> createState() => _OwnerGstScreenState();
}

class _OwnerGstScreenState extends ConsumerState<OwnerGstScreen> {
  final _gstin = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _gstinError;
  bool _sent = false;

  @override
  void dispose() {
    _gstin.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final gstin = _gstin.text.trim().toUpperCase();
    final name = _name.text.trim();
    final problem = gstinProblem(gstin);
    setState(() {
      _error = null;
      _sent = false;
      _gstinError = problem == null
          ? null
          : gstinProblemText(l10n, problem, gstin.length);
    });
    if (_gstinError != null || name.length < 2) {
      if (name.length < 2) setState(() => _error = l10n.gstNameRequired);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(ownerRepositoryProvider)
          .addGstRegistration(gstin: gstin, legalName: name);
      if (!mounted) return;
      _gstin.clear();
      _name.clear();
      setState(() {
        _busy = false;
        _sent = true;
      });
      ref.invalidate(ownerGstRegistrationsProvider);
    } on ApiException catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _gstinError = failure.fieldErrors['gstin']?.first;
        _error = _gstinError == null ? l10n.describe(failure) : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final registrations = ref.watch(ownerGstRegistrationsProvider);

    return AppScaffold(
      title: l10n.gstTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.gstIntro, style: context.text.bodySmall),
          const Gap.md(),
          registrations.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AppBanner(
              tone: StatusTone.danger,
              message: error is ApiException
                  ? l10n.describe(error)
                  : l10n.gstLoadFailed,
            ),
            data: (items) => items.isEmpty
                ? Text(l10n.gstNone, style: context.text.bodySmall)
                : Column(
                    children: [
                      for (final item in items) ...[
                        _RegistrationCard(item: item),
                        const Gap.sm(),
                      ],
                    ],
                  ),
          ),
          const Gap.lg(),
          Text(l10n.gstAddTitle, style: context.text.h3),
          const Gap.sm(),
          AppTextField(
            label: l10n.gstGstin,
            controller: _gstin,
            errorText: _gstinError,
            textCapitalization: TextCapitalization.characters,
            // Letters and digits only, shown in capitals, never more than 15.
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9A-Za-z]')),
              LengthLimitingTextInputFormatter(15),
              const _UpperCase(),
            ],
            enabled: !_busy,
          ),
          const Gap.sm(),
          AppTextField(
            label: l10n.gstLegalName,
            controller: _name,
            textCapitalization: TextCapitalization.words,
            enabled: !_busy,
          ),
          if (_error != null) ...[
            const Gap.sm(),
            AppBanner(tone: StatusTone.danger, message: _error!),
          ],
          if (_sent) ...[
            const Gap.sm(),
            AppBanner(tone: StatusTone.success, message: l10n.gstSent),
          ],
          const Gap.md(),
          PrimaryButton(
            label: l10n.gstSubmit,
            isLoading: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _RegistrationCard extends StatelessWidget {
  const _RegistrationCard({required this.item});

  final GstRegistration item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = switch (item.status) {
      GstRegistrationStatus.verified => l10n.gstVerified,
      GstRegistrationStatus.rejected => l10n.gstRejected,
      _ when item.nameMatches == false => l10n.gstNameMismatch(
        item.serviceLegalName ?? '',
      ),
      _ => l10n.gstPending,
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.gstin, style: context.text.h3),
          const Gap.xs(),
          Text(
            '${item.legalName} · ${l10n.gstState(item.stateCode)}',
            style: context.text.bodySmall,
          ),
          const Gap.xs(),
          Text(status, style: context.text.bodySmall),
          if (item.rejectionReason != null) ...[
            const Gap.xs(),
            Text(item.rejectionReason!, style: context.text.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// The exact reason a GSTIN's format is wrong.
String gstinProblemText(
  AppLocalizations l10n,
  GstinProblem problem,
  int length,
) => switch (problem) {
  GstinProblem.characters => l10n.gstErrCharacters,
  GstinProblem.length => l10n.gstErrLength(length),
  GstinProblem.stateCode => l10n.gstErrState,
  GstinProblem.pan => l10n.gstErrPan,
  GstinProblem.panHolderType => l10n.gstErrHolderType,
  GstinProblem.entityNumber => l10n.gstErrEntity,
  GstinProblem.defaultCharacter => l10n.gstErrZ,
  GstinProblem.checksum => l10n.gstErrChecksum,
};

/// Shows what is typed in capitals.
class _UpperCase extends TextInputFormatter {
  const _UpperCase();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
