import 'package:app/app/routes.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/config/app_identity.dart';
import 'package:app/core/files/picked_file.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/validation/identity_numbers.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_text_field.dart';
import 'package:app/core/widgets/confirm_dialog.dart';
import 'package:app/core/widgets/otp_field.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:app/features/owner/data/models/owner_document.dart';
import 'package:app/features/owner/data/owner_repository.dart';
import 'package:app/features/owner/state/owner_documents_notifier.dart';
import 'package:app/features/owner/ui/owner_documents_section.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The owner's two identity cards: Aadhaar and PAN. Each is added with its
/// number, which is checked as it is typed; a wrong number is not sent and
/// the owner is asked to verify it. The server checks it again, and its
/// identity verification service confirms whether it is genuine: a PAN at
/// once, an Aadhaar with an OTP sent to the Aadhaar-linked mobile.
class IdentityCardsSection extends ConsumerWidget {
  const IdentityCardsSection({
    required this.canRemove,
    this.onComplete,
    super.key,
  });

  final bool canRemove;

  /// Called right after the owner saves the second card, so the screen can
  /// move on (to the home page).
  final VoidCallback? onComplete;

  static String cardLabel(AppLocalizations l10n, IdentityCardKind kind) =>
      switch (kind) {
        IdentityCardKind.aadhaar => l10n.identityAadhaar,
        IdentityCardKind.pan => l10n.identityPan,
      };

  /// The uploaded card of this kind, if any.
  static OwnerDocument? cardOf(
    List<OwnerDocument> documents,
    IdentityCardKind kind,
  ) {
    for (final document in documents) {
      if (document.type == OwnerDocumentType.identity &&
          IdentityNumbers.isStoredAs(kind, document.documentNumber)) {
        return document;
      }
    }
    return null;
  }

  /// The OTP step for an Aadhaar card. Returns once the sheet is closed.
  ///
  /// [knownNumber] is the full Aadhaar number the owner typed a moment ago
  /// when adding the card; it is not asked for again. Later (the app keeps
  /// only the last 4 digits) the owner types it once more.
  static Future<void> verifyAadhaar(
    BuildContext context,
    OwnerDocument card, {
    String? knownNumber,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _AadhaarOtpSheet(card: card, knownNumber: knownNumber),
  );

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
    final documents =
        ref.watch(ownerDocumentsProvider).valueOrNull?.documents ??
        const <OwnerDocument>[];
    final busy = ref.watch(ownerDocumentsProvider).valueOrNull?.isBusy ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.identityCardsTitle, style: text.h3),
        const Gap.xs(),
        Text(
          l10n.identityCardsHint,
          style: text.bodySmall.copyWith(color: colors.textSecondary),
        ),
        const Gap.md(),
        for (final (index, kind) in IdentityCardKind.values.indexed) ...[
          if (index > 0) const Gap.sm(),
          Builder(
            builder: (context) {
              final card = cardOf(documents, kind);
              final note = card == null
                  ? null
                  : scanNote(l10n, card.scanStatus);
              return AppCard(
                child: Row(
                  children: [
                    Icon(
                      card == null
                          ? Icons.badge_outlined
                          : Icons.verified_user_outlined,
                      color: card == null
                          ? colors.textSecondary
                          : colors.success.solid,
                    ),
                    const Gap.md(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cardLabel(l10n, kind), style: text.body),
                          Text(
                            card == null
                                ? l10n.identityNotAdded
                                : l10n.identityAddedNumber(
                                    card.documentNumber ?? '',
                                  ),
                            style: text.bodySmall.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          if (note != null)
                            Text(
                              note,
                              style: text.bodySmall.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          if (card?.identityStatus == 'verified')
                            Text(
                              l10n.identityVerified,
                              style: text.bodySmall.copyWith(
                                color: colors.success.solid,
                              ),
                            )
                          else if (card?.identityStatus == 'not_verified')
                            Text(
                              l10n.identityNeedsReview,
                              style: text.bodySmall.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          if (card != null && card.awaitsAadhaarOtp)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton(
                                onPressed: busy
                                    ? null
                                    : () => verifyAadhaar(context, card),
                                child: Text(l10n.identityVerifyWithOtp),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (card == null)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final withOtp =
                                    kind == IdentityCardKind.aadhaar &&
                                    (ref
                                            .read(ownerDocumentsProvider)
                                            .valueOrNull
                                            ?.identity
                                            .aadhaarNeedsOtp ??
                                        false);
                                final saved =
                                    await showModalBottomSheet<String>(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (context) => withOtp
                                          ? const _AadhaarCardSheet()
                                          : _IdentityCardSheet(kind: kind),
                                    );
                                if (saved == null || !context.mounted) return;
                                // Aadhaar done: straight on to the PAN details.
                                if (saved == _AadhaarCardSheet.addPan &&
                                    cardOf(
                                          ref
                                                  .read(ownerDocumentsProvider)
                                                  .valueOrNull
                                                  ?.documents ??
                                              const <OwnerDocument>[],
                                          IdentityCardKind.pan,
                                        ) ==
                                        null) {
                                  await showModalBottomSheet<String>(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (context) =>
                                        const _IdentityCardSheet(
                                          kind: IdentityCardKind.pan,
                                        ),
                                  );
                                  if (!context.mounted) return;
                                }
                                final now =
                                    ref
                                        .read(ownerDocumentsProvider)
                                        .valueOrNull
                                        ?.documents ??
                                    const <OwnerDocument>[];
                                final both = IdentityCardKind.values.every(
                                  (kind) => cardOf(now, kind) != null,
                                );
                                if (both) onComplete?.call();
                              },
                        child: Text(
                          l10n.identityAddCard(cardLabel(l10n, kind)),
                        ),
                      )
                    else if (canRemove)
                      IconButton(
                        tooltip: l10n.documentRemove,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: busy
                            ? null
                            : () => _remove(context, ref, card),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Number and file for one card. "Save card" checks the number first and
/// asks the owner to verify it when it is wrong; nothing is sent until it is
/// right and a file is chosen.
class _IdentityCardSheet extends ConsumerStatefulWidget {
  const _IdentityCardSheet({required this.kind});

  final IdentityCardKind kind;

  @override
  ConsumerState<_IdentityCardSheet> createState() => _IdentityCardSheetState();
}

class _IdentityCardSheetState extends ConsumerState<_IdentityCardSheet> {
  final _number = TextEditingController();
  PickedFile? _file;
  DateTime? _dateOfBirth;
  bool _checked = false;
  bool _fileMissing = false;
  bool _saving = false;

  bool get _needsDateOfBirth =>
      widget.kind == IdentityCardKind.pan &&
      (ref
              .read(ownerDocumentsProvider)
              .valueOrNull
              ?.identity
              .panNeedsDateOfBirth ??
          false);

  static String _ymd(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day - 1),
    );
    if (picked != null && mounted) setState(() => _dateOfBirth = picked);
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  bool get _numberOk => IdentityNumbers.isValid(widget.kind, _number.text);

  Future<void> _pick() async {
    try {
      final file = await ref
          .read(filePickerServiceProvider)
          .pick(extensions: const ['pdf', 'jpg', 'jpeg', 'png']);
      if (file != null && mounted) {
        setState(() {
          _file = file;
          _fileMissing = false;
        });
      }
    } on PickException catch (error) {
      ref.read(ownerDocumentsProvider.notifier).pickFailed(error.problem);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    setState(() {
      _checked = true;
      _fileMissing = _file == null;
    });
    final file = _file;
    if (!_numberOk || file == null) return;
    if (_needsDateOfBirth && _dateOfBirth == null) return;

    setState(() => _saving = true);
    final saved = await ref
        .read(ownerDocumentsProvider.notifier)
        .upload(
          OwnerDocumentType.identity,
          file,
          documentNumber: widget.kind == IdentityCardKind.pan
              ? IdentityNumbers.normalisePan(_number.text)
              : IdentityNumbers.aadhaarDigits(_number.text),
          identityKind: widget.kind.wire,
          dateOfBirth: _needsDateOfBirth && _dateOfBirth != null
              ? _ymd(_dateOfBirth!)
              : null,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    // The Aadhaar number goes on to the OTP step, so it is typed only once.
    if (saved) {
      Navigator.of(context).pop(
        widget.kind == IdentityCardKind.aadhaar
            ? IdentityNumbers.aadhaarDigits(_number.text)
            : '',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final aadhaar = widget.kind == IdentityCardKind.aadhaar;
    final failure = ref.watch(ownerDocumentsProvider).valueOrNull?.failure;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.identityAddCard(
                  IdentityCardsSection.cardLabel(l10n, widget.kind),
                ),
                style: text.h3,
              ),
              const Gap.md(),
              AppTextField(
                label: aadhaar
                    ? l10n.identityAadhaarNumber
                    : l10n.identityPanNumber,
                controller: _number,
                autofocus: true,
                hintText: aadhaar ? '1234 5678 9012' : 'ABCDE1234F',
                helperText: aadhaar
                    ? l10n.identityAadhaarHelp
                    : l10n.identityPanHelp,
                errorText: _checked && !_numberOk
                    ? (aadhaar
                          ? l10n.identityVerifyAadhaar
                          : l10n.identityVerifyPan)
                    : null,
                keyboardType: aadhaar
                    ? TextInputType.number
                    : TextInputType.text,
                textCapitalization: aadhaar
                    ? TextCapitalization.none
                    : TextCapitalization.characters,
                inputFormatters: <TextInputFormatter>[
                  IdentityNumbers.formatter(widget.kind),
                ],
                onChanged: (_) => setState(() {}),
              ),
              if (aadhaar) ...[
                const Gap.xs(),
                Text(
                  l10n.identityAadhaarPrivacy,
                  style: text.bodySmall.copyWith(color: colors.textSecondary),
                ),
              ],
              if (_needsDateOfBirth) ...[
                const Gap.md(),
                Text(l10n.identityPanDateOfBirth, style: text.body),
                const Gap.xs(),
                SecondaryButton(
                  label: _dateOfBirth == null
                      ? l10n.identityPanDateOfBirthChoose
                      : MaterialLocalizations.of(
                          context,
                        ).formatMediumDate(_dateOfBirth!),
                  onPressed: _saving ? null : _pickDateOfBirth,
                ),
                const Gap.xs(),
                Text(
                  _checked && _dateOfBirth == null
                      ? l10n.identityPanDateOfBirthNeeded
                      : l10n.identityPanDateOfBirthHelp,
                  style: text.bodySmall.copyWith(
                    color: _checked && _dateOfBirth == null
                        ? colors.danger.solid
                        : colors.textSecondary,
                  ),
                ),
              ],
              const Gap.md(),
              SecondaryButton(
                label: _file == null
                    ? l10n.identityChooseFile
                    : l10n.identityFileChosen(_file!.name),
                onPressed: _saving ? null : _pick,
              ),
              if (_fileMissing) ...[
                const Gap.xs(),
                Text(
                  l10n.identityFileNeeded,
                  style: text.bodySmall.copyWith(color: colors.danger.solid),
                ),
              ],
              if (failure != null && _checked) ...[
                const Gap.sm(),
                AppBanner(
                  tone: StatusTone.danger,
                  message: l10n.describe(failure),
                ),
              ],
              const Gap.lg(),
              PrimaryButton(
                label: l10n.identitySave,
                isLoading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AadhaarStep { number, otp, file, result }

/// Adding the Aadhaar card when it is confirmed by OTP, on one sheet:
/// 1. the number (and consent), 2. the OTP from the Aadhaar-linked mobile,
/// 3. a photo or PDF of the card, 4. whether it is verified, then on to the
/// PAN details. The number is typed once. A service problem never stops the
/// owner: the card is added and waits for a person.
class _AadhaarCardSheet extends ConsumerStatefulWidget {
  const _AadhaarCardSheet();

  /// Returned when the owner goes on to add the PAN card.
  static const addPan = 'pan';

  @override
  ConsumerState<_AadhaarCardSheet> createState() => _AadhaarCardSheetState();
}

class _AadhaarCardSheetState extends ConsumerState<_AadhaarCardSheet> {
  final _number = TextEditingController();
  final _otp = TextEditingController();
  _AadhaarStep _step = _AadhaarStep.number;
  bool _consent = false;
  bool _checked = false;
  bool _working = false;
  bool _fileMissing = false;
  PickedFile? _file;

  /// A note for the current step (a wrong OTP, a service problem).
  String? _message;
  StatusTone _tone = StatusTone.warning;
  ApiException? _failure;
  OwnerDocument? _saved;

  @override
  void dispose() {
    _number.dispose();
    _otp.dispose();
    super.dispose();
  }

  bool get _numberOk =>
      IdentityNumbers.isValid(IdentityCardKind.aadhaar, _number.text);

  String get _digits => IdentityNumbers.aadhaarDigits(_number.text);

  String get _masked =>
      'XXXX XXXX ${_digits.length >= 4 ? _digits.substring(_digits.length - 4) : ''}';

  Future<void> _run(Future<void> Function() work) async {
    setState(() {
      _working = true;
      _failure = null;
    });
    try {
      await work();
    } on ApiException catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _sendOtp() async {
    setState(() => _checked = true);
    if (!_numberOk || !_consent) return;
    await _run(() async {
      final reply = await ref
          .read(ownerRepositoryProvider)
          .sendAadhaarOtpBeforeUpload(_digits);
      if (!mounted) return;
      setState(() {
        if (reply.sent) {
          _otp.clear();
          _message = null;
          _step = _AadhaarStep.otp;
        } else if (reply.status == 'unavailable') {
          // No answer from the service: add the card; a person checks it.
          _message = context.l10n.identityOtpSkipped;
          _tone = StatusTone.info;
          _step = _AadhaarStep.file;
        } else {
          _message = reply.message;
          _tone = StatusTone.warning;
        }
      });
    });
  }

  Future<void> _verifyOtp() async {
    if (_otp.text.length != 6 || _working) return;
    await _run(() async {
      final reply = await ref
          .read(ownerRepositoryProvider)
          .verifyAadhaarOtpBeforeUpload(_otp.text);
      if (!mounted) return;
      final l10n = context.l10n;
      setState(() {
        if (reply.otpRejected) {
          _otp.clear();
          final left = reply.attemptsLeft ?? 0;
          _tone = StatusTone.warning;
          _message = left > 0
              ? '${reply.message} ${l10n.identityOtpAttemptsLeft(left)}'
              : reply.message;
          if (left == 0) _step = _AadhaarStep.number;
        } else {
          _message = reply.verified
              ? l10n.identityOtpConfirmed
              : l10n.identityOtpSkipped;
          _tone = reply.verified ? StatusTone.success : StatusTone.info;
          _step = _AadhaarStep.file;
        }
      });
    });
  }

  Future<void> _pick() async {
    try {
      final file = await ref
          .read(filePickerServiceProvider)
          .pick(extensions: const ['pdf', 'jpg', 'jpeg', 'png']);
      if (file != null && mounted) {
        setState(() {
          _file = file;
          _fileMissing = false;
        });
      }
    } on PickException catch (error) {
      ref.read(ownerDocumentsProvider.notifier).pickFailed(error.problem);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _saveCard() async {
    final file = _file;
    setState(() => _fileMissing = file == null);
    if (file == null) return;

    setState(() => _working = true);
    final notifier = ref.read(ownerDocumentsProvider.notifier);
    final saved = await notifier.upload(
      OwnerDocumentType.identity,
      file,
      documentNumber: _digits,
      identityKind: IdentityCardKind.aadhaar.wire,
    );
    if (!mounted) return;
    final state = ref.read(ownerDocumentsProvider).valueOrNull;
    setState(() {
      _working = false;
      if (saved) {
        _saved = IdentityCardsSection.cardOf(
          state?.documents ?? const <OwnerDocument>[],
          IdentityCardKind.aadhaar,
        );
        _message = null;
        _step = _AadhaarStep.result;
      } else {
        _failure = state?.failure;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final failure = _failure;
    final verified = _saved?.identityStatus == 'verified';

    final children = <Widget>[
      Text(l10n.identityAddCard(l10n.identityAadhaar), style: text.h3),
      const Gap.xs(),
      Text(switch (_step) {
        _AadhaarStep.number => l10n.identityOtpIntro,
        _AadhaarStep.otp => l10n.identityOtpSentTo,
        _AadhaarStep.file => l10n.identityStepFile,
        _AadhaarStep.result => l10n.identityAddedNumber(_masked),
      }, style: text.bodySmall.copyWith(color: colors.textSecondary)),
      const Gap.md(),
      ...switch (_step) {
        _AadhaarStep.number => [
          AppTextField(
            label: l10n.identityAadhaarNumber,
            controller: _number,
            autofocus: true,
            hintText: '1234 5678 9012',
            helperText: l10n.identityAadhaarHelp,
            errorText: _checked && !_numberOk
                ? l10n.identityVerifyAadhaar
                : null,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              IdentityNumbers.formatter(IdentityCardKind.aadhaar),
            ],
            onChanged: (_) => setState(() {}),
          ),
          const Gap.xs(),
          Text(
            l10n.identityAadhaarPrivacy,
            style: text.bodySmall.copyWith(color: colors.textSecondary),
          ),
          const Gap.sm(),
          CheckboxListTile(
            value: _consent,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: _working
                ? null
                : (value) => setState(() => _consent = value ?? false),
            title: Text(
              l10n.identityOtpConsent(appDisplayName),
              style: text.bodySmall,
            ),
          ),
          if (_checked && !_consent)
            Text(
              l10n.identityOtpConsentNeeded,
              style: text.bodySmall.copyWith(color: colors.danger.solid),
            ),
        ],
        _AadhaarStep.otp => [
          Text(l10n.identityAddedNumber(_masked), style: text.body),
          const Gap.sm(),
          OtpField(
            label: l10n.identityOtpCode,
            length: 6,
            controller: _otp,
            autofocus: true,
            enabled: !_working,
            onCompleted: (_) => _verifyOtp(),
          ),
        ],
        _AadhaarStep.file => [
          Text(l10n.identityAddedNumber(_masked), style: text.body),
          const Gap.sm(),
          SecondaryButton(
            label: _file == null
                ? l10n.identityChooseFile
                : l10n.identityFileChosen(_file!.name),
            onPressed: _working ? null : _pick,
          ),
          if (_fileMissing) ...[
            const Gap.xs(),
            Text(
              l10n.identityFileNeeded,
              style: text.bodySmall.copyWith(color: colors.danger.solid),
            ),
          ],
        ],
        _AadhaarStep.result => [
          AppBanner(
            tone: verified ? StatusTone.success : StatusTone.info,
            message: verified
                ? l10n.identityAadhaarResultVerified
                : l10n.identityAadhaarResultReview,
          ),
        ],
      },
      if (_message != null && _step != _AadhaarStep.result) ...[
        const Gap.sm(),
        AppBanner(tone: _tone, message: _message!),
      ],
      if (failure != null) ...[
        const Gap.sm(),
        AppBanner(tone: StatusTone.danger, message: l10n.describe(failure)),
      ],
      const Gap.lg(),
      switch (_step) {
        _AadhaarStep.number => PrimaryButton(
          label: l10n.identityOtpSend,
          isLoading: _working,
          onPressed: _working ? null : _sendOtp,
        ),
        _AadhaarStep.otp => PrimaryButton(
          label: l10n.identityOtpVerify,
          isLoading: _working,
          onPressed: _working ? null : _verifyOtp,
        ),
        _AadhaarStep.file => PrimaryButton(
          label: l10n.identitySave,
          isLoading: _working,
          onPressed: _working ? null : _saveCard,
        ),
        _AadhaarStep.result => PrimaryButton(
          label: l10n.identityAddPanDetails,
          onPressed: () => Navigator.of(context).pop(_AadhaarCardSheet.addPan),
        ),
      },
      if (_step == _AadhaarStep.otp) ...[
        const Gap.sm(),
        TextButton(
          onPressed: _working
              ? null
              : () => setState(() {
                  _step = _AadhaarStep.number;
                  _message = null;
                }),
          child: Text(l10n.identityOtpResend),
        ),
      ],
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Confirms an Aadhaar card with the OTP UIDAI sends to the mobile linked to
/// the Aadhaar. First the owner types the number again and agrees to the
/// check; then types the OTP. A service problem closes the sheet with a note:
/// the card then waits for a person and the owner is never blamed for it.
class _AadhaarOtpSheet extends ConsumerStatefulWidget {
  const _AadhaarOtpSheet({required this.card, this.knownNumber});

  final OwnerDocument card;

  /// The number typed when the card was added; then it is not asked again.
  final String? knownNumber;

  @override
  ConsumerState<_AadhaarOtpSheet> createState() => _AadhaarOtpSheetState();
}

class _AadhaarOtpSheetState extends ConsumerState<_AadhaarOtpSheet> {
  final _number = TextEditingController();
  final _otp = TextEditingController();
  bool _consent = false;
  bool _checked = false;
  bool _sent = false;
  bool _working = false;
  String? _message;
  ApiException? _failure;

  bool get _numberKnown => widget.knownNumber != null;

  @override
  void initState() {
    super.initState();
    final known = widget.knownNumber;
    if (known != null) _number.text = known;
  }

  @override
  void dispose() {
    _number.dispose();
    _otp.dispose();
    super.dispose();
  }

  bool get _numberOk =>
      IdentityNumbers.isValid(IdentityCardKind.aadhaar, _number.text);

  Future<void> _send() async {
    setState(() {
      _checked = true;
      _failure = null;
    });
    if (!_numberOk || !_consent) return;

    setState(() => _working = true);
    try {
      final reply = await ref
          .read(ownerRepositoryProvider)
          .sendAadhaarOtp(
            widget.card.id,
            IdentityNumbers.aadhaarDigits(_number.text),
          );
      if (!mounted) return;
      if (reply.sent) {
        _otp.clear();
        setState(() {
          _sent = true;
          _message = null;
        });
      } else {
        await _finish(reply.message);
      }
    } on ApiException catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _verify() async {
    if (_otp.text.length != 6 || _working) return;
    setState(() {
      _working = true;
      _failure = null;
    });
    try {
      final reply = await ref
          .read(ownerRepositoryProvider)
          .verifyAadhaarOtp(widget.card.id, _otp.text);
      if (!mounted) return;
      if (reply.otpRejected) {
        _otp.clear();
        final left = reply.attemptsLeft ?? 0;
        setState(() {
          _message = left > 0
              ? '${reply.message} ${context.l10n.identityOtpAttemptsLeft(left)}'
              : reply.message;
          if (left == 0) _sent = false;
        });
      } else {
        await _finish(
          reply.verified ? context.l10n.identityOtpVerified : reply.message,
        );
      }
    } on ApiException catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _finish(String message) async {
    await ref.read(ownerDocumentsProvider.notifier).reload();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    if (message.isNotEmpty) {
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final failure = _failure;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.identityOtpTitle, style: text.h3),
              const Gap.xs(),
              Text(
                _sent ? l10n.identityOtpSentTo : l10n.identityOtpIntro,
                style: text.bodySmall.copyWith(color: colors.textSecondary),
              ),
              const Gap.md(),
              if (!_sent) ...[
                if (_numberKnown)
                  Text(
                    l10n.identityAddedNumber(widget.card.documentNumber ?? ''),
                    style: text.body,
                  )
                else
                  AppTextField(
                    label: l10n.identityAadhaarNumber,
                    controller: _number,
                    autofocus: true,
                    hintText: '1234 5678 9012',
                    helperText: l10n.identityOtpNumberAgain,
                    errorText: _checked && !_numberOk
                        ? l10n.identityVerifyAadhaar
                        : null,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      IdentityNumbers.formatter(IdentityCardKind.aadhaar),
                    ],
                    onChanged: (_) => setState(() {}),
                  ),
                const Gap.sm(),
                CheckboxListTile(
                  value: _consent,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: _working
                      ? null
                      : (value) => setState(() => _consent = value ?? false),
                  title: Text(
                    l10n.identityOtpConsent(appDisplayName),
                    style: text.bodySmall,
                  ),
                ),
                if (_checked && !_consent)
                  Text(
                    l10n.identityOtpConsentNeeded,
                    style: text.bodySmall.copyWith(color: colors.danger.solid),
                  ),
              ] else
                OtpField(
                  label: l10n.identityOtpCode,
                  length: 6,
                  controller: _otp,
                  autofocus: true,
                  enabled: !_working,
                  onCompleted: (_) => _verify(),
                ),
              if (_message != null) ...[
                const Gap.sm(),
                AppBanner(tone: StatusTone.warning, message: _message!),
              ],
              if (failure != null) ...[
                const Gap.sm(),
                AppBanner(
                  tone: StatusTone.danger,
                  message: l10n.describe(failure),
                ),
              ],
              const Gap.lg(),
              PrimaryButton(
                label: _sent ? l10n.identityOtpVerify : l10n.identityOtpSend,
                isLoading: _working,
                onPressed: _working ? null : (_sent ? _verify : _send),
              ),
              const Gap.sm(),
              if (_sent)
                TextButton(
                  onPressed: _working
                      ? null
                      : () => setState(() {
                          _sent = false;
                          _message = null;
                        }),
                  child: Text(l10n.identityOtpResend),
                )
              else
                TextButton(
                  onPressed: _working
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(l10n.identityOtpLater),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// After both cards are saved: a short note, then the home page (the owner
/// area once the owner is approved, the app's home before that).
Future<void> goHomeAfterIdentityCards(
  BuildContext context,
  WidgetRef ref, {
  required bool ownerArea,
}) async {
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(context.l10n.identityCardsSaved)));
  if (ownerArea) {
    context.go(Routes.ownerBookings);
    return;
  }
  await leaveApplicationForHome(context, ref);
}

/// An applicant waiting for review goes to the app's home. Their sign-up as
/// an owner is finished (the application is sent), so the app stops
/// bringing them back to the application page; it stays under Profile.
Future<void> leaveApplicationForHome(
  BuildContext context,
  WidgetRef ref,
) async {
  await ref.read(sessionControllerProvider.notifier).finishRegistration();
  if (context.mounted) context.go(Routes.explore);
}
