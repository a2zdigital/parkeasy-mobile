import 'package:app/app/routes.dart';
import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/scanning/qr_scanner.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/app_segmented_control.dart';
import 'package:app/core/widgets/app_text_field.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/gate/data/gate_repository.dart';
import 'package:app/features/gate/ui/check_out_confirm_sheet.dart';
import 'package:app/features/owner/data/owner_repository.dart';
import 'package:app/features/owner/state/owner_booking_notifier.dart';
import 'package:app/features/owner/state/owner_lists.dart';
import 'package:app/features/owner/ui/owner_common.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Gate check-in: the owner types the code from the customer's booking and
/// lands on that booking, checked in; or scans the QR code that holds
/// the same text.
class OwnerCheckInScreen extends ConsumerStatefulWidget {
  const OwnerCheckInScreen({this.bookingId, this.checkOut = false, super.key});

  /// Opens in check-out mode (for a parked booking).
  final bool checkOut;

  /// The booking this was opened from. Checking that booking in returns
  /// to it; another booking's code opens that booking instead.
  final String? bookingId;

  @override
  ConsumerState<OwnerCheckInScreen> createState() => _OwnerCheckInScreenState();
}

class _OwnerCheckInScreenState extends ConsumerState<OwnerCheckInScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  late bool _checkingOut = widget.checkOut;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    if (_busy) return;
    final scanned = await ref.read(qrScannerProvider).scan(context);
    if (scanned == null || !mounted) return;
    // A signed pass is sent exactly as scanned; it is never shown or edited.
    if (isGatePass(scanned)) {
      await _submit(scanned.trim());
      return;
    }
    _code.text = scanned;
    await _submit();
  }

  Future<void> _submit([String? pass]) async {
    if (_busy) return;
    final l10n = context.l10n;
    final code =
        pass ?? _code.text.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = l10n.ownerCheckInEmpty);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(ownerRepositoryProvider);
      final Booking booking;
      if (_checkingOut) {
        // Verify first and show the booking; nothing changes until confirmed.
        final found = await repository.verifyCheckOut(code);
        if (!mounted) return;
        // No spinner while the person reads and decides.
        setState(() => _busy = false);
        final choice = await confirmCheckOut(context, found);
        if (choice == null || !mounted) return;
        setState(() => _busy = true);
        booking = await repository.checkOutByCode(code, choice);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.checkOutDone(booking.reference))),
          );
        }
      } else {
        booking = await repository.checkInByCode(code);
      }
      ref.invalidate(ownerBookingsProvider);
      final from = widget.bookingId;
      if (from != null) ref.invalidate(ownerBookingProvider(from));
      if (!mounted) return;
      if (booking.id == from) {
        context.pop();
      } else {
        context.pushReplacement(Routes.ownerBooking(booking.id));
      }
    } on ApiException catch (failure) {
      if (!mounted) return;
      final out = _checkingOut;
      setState(() {
        _busy = false;
        _error = switch (failure.code) {
          ApiErrorCode.checkInCodeNotFound => l10n.errCheckInCodeNotFound,
          ApiErrorCode.checkOutCodeNotFound => l10n.errCheckOutCodeNotFound,
          ApiErrorCode.gatePassExpired => l10n.errGatePassExpired,
          ApiErrorCode.alreadyCheckedOut => l10n.errAlreadyCheckedOut,
          ApiErrorCode.checkInCodeAtCheckOut => l10n.errCheckInCodeAtCheckOut,
          ApiErrorCode.extraTimeAlreadyCollected => l10n.errAlreadyCheckedOut,
          // The server or the connection failed: nothing was completed,
          // and the person can try again.
          ApiErrorCode.network when out => l10n.errCheckOutFailed,
          ApiErrorCode.timeout when out => l10n.errCheckOutTimeout,
          ApiErrorCode.internalError ||
          ApiErrorCode.serviceUnavailable ||
          ApiErrorCode.unknown when out => l10n.errCheckOutServer,
          ApiErrorCode.bookingPaymentRequired => l10n.errBookingPaymentRequired,
          ApiErrorCode.bookingPaymentAmountMismatch =>
            l10n.errBookingPaymentAmountMismatch,
          ApiErrorCode.extraTimeAmountChanged => l10n.errExtraTimeAmountChanged,
          ApiErrorCode.extraTimePaymentRequired =>
            l10n.errExtraTimePaymentRequired,
          ApiErrorCode.checkOutNotAllowed => l10n.errCheckOutNotAllowed,
          ApiErrorCode.checkInNotAllowed || ApiErrorCode.invalidBookingState
              when _checkingOut =>
            l10n.errCheckOutNotAllowed,
          ApiErrorCode.checkInNotAllowed => checkInRefusalText(l10n, failure),
          ApiErrorCode.bookingExpired => l10n.bannerNoShow,
          ApiErrorCode.invalidBookingState => l10n.errCheckInBookingState,
          _ => ownerAccessText(l10n, failure) ?? l10n.describe(failure),
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final error = _error;

    return AppScaffold(
      title: l10n.ownerCheckInTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap.md(),
          AppSegmentedControl<bool>(
            segments: [(false, l10n.gateCheckIn), (true, l10n.gateCheckOut)],
            selected: _checkingOut,
            onChanged: (out) => setState(() {
              _checkingOut = out;
              _error = null;
            }),
          ),
          const Gap.md(),
          SecondaryButton(
            label: l10n.ownerCheckInScan,
            onPressed: _busy ? null : _scan,
          ),
          const Gap.md(),
          AppTextField(
            label: _checkingOut
                ? l10n.ownerCheckOutCodeLabel
                : l10n.ownerCheckInCodeLabel,
            hintText: l10n.ownerCheckInCodeHint,
            helperText: _checkingOut
                ? l10n.ownerCheckOutHelp
                : l10n.ownerCheckInHelp,
            controller: _code,
            enabled: !_busy,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 \-]')),
              LengthLimitingTextInputFormatter(12),
            ],
            onSubmitted: (_) => _submit(),
          ),
          if (error != null) ...[
            const Gap.sm(),
            AppBanner(tone: StatusTone.danger, message: error),
          ],
        ],
      ),
      bottom: PrimaryButton(
        label: _checkingOut ? l10n.gateCheckOut : l10n.ownerCheckInSubmit,
        isLoading: _busy,
        onPressed: _submit,
      ),
    );
  }
}
