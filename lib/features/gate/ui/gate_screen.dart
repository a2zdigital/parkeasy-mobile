import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/scanning/qr_scanner.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/app_segmented_control.dart';
import 'package:app/core/widgets/app_text_field.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/gate/data/gate_repository.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The gate, for an attendant: check a vehicle in or out by scanning the
/// customer's QR code or typing their code. Shows what happened and stays
/// on this screen for the next car.
class GateScreen extends ConsumerStatefulWidget {
  const GateScreen({super.key});

  @override
  ConsumerState<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends ConsumerState<GateScreen> {
  final _code = TextEditingController();
  bool _checkingOut = false;
  bool _busy = false;
  String? _error;
  ({Booking booking, bool out})? _done;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    if (_busy) return;
    final scanned = await ref.read(qrScannerProvider).scan(context);
    if (scanned == null || !mounted) return;
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
      _done = null;
    });
    final out = _checkingOut;
    try {
      final gate = ref.read(gateRepositoryProvider);
      final booking = out
          ? await gate.checkOut(code)
          : await gate.checkIn(code);
      if (!mounted) return;
      _code.clear();
      setState(() {
        _busy = false;
        _done = (booking: booking, out: out);
      });
    } on ApiException catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (failure.code) {
          ApiErrorCode.checkInCodeNotFound => l10n.gateCodeNotFound,
          ApiErrorCode.checkOutNotAllowed => l10n.errCheckOutNotAllowed,
          ApiErrorCode.checkInNotAllowed || ApiErrorCode.invalidBookingState =>
            out ? l10n.errCheckOutNotAllowed : l10n.errCheckInNotAllowed,
          _ => l10n.describe(failure),
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final facilities = ref.watch(gateFacilitiesProvider);
    final error = _error;
    final done = _done;

    final names = facilities.valueOrNull ?? const <GateFacility>[];
    if (facilities.hasValue && names.isEmpty) {
      return AppScaffold(
        title: l10n.gateTitle,
        body: EmptyState(
          icon: Icons.lock_outline,
          title: l10n.gateNoFacilitiesTitle,
          body: l10n.gateNoFacilitiesBody,
        ),
      );
    }

    return AppScaffold(
      title: l10n.gateTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap.md(),
          if (names.isNotEmpty)
            Text(
              l10n.gateAt(names.map((f) => f.name).join(', ')),
              style: text.bodySmall.copyWith(color: colors.textSecondary),
            ),
          const Gap.md(),
          AppSegmentedControl<bool>(
            segments: [(false, l10n.gateCheckIn), (true, l10n.gateCheckOut)],
            selected: _checkingOut,
            onChanged: (out) => setState(() {
              _checkingOut = out;
              _error = null;
              _done = null;
            }),
          ),
          const Gap.lg(),
          SecondaryButton(
            label: l10n.ownerCheckInScan,
            onPressed: _busy ? null : _scan,
          ),
          const Gap.md(),
          AppTextField(
            label: l10n.ownerCheckInCodeLabel,
            hintText: l10n.ownerCheckInCodeHint,
            controller: _code,
            enabled: !_busy,
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
          if (done != null) ...[
            const Gap.sm(),
            AppBanner(
              tone: StatusTone.success,
              message: done.out
                  ? l10n.gateCheckedOut(done.booking.reference)
                  : done.booking.spaceLabel == null
                  ? l10n.gateCheckedIn(done.booking.reference)
                  : l10n.gateCheckedInBay(
                      done.booking.reference,
                      done.booking.spaceLabel!,
                    ),
            ),
          ],
        ],
      ),
      bottom: PrimaryButton(
        label: _checkingOut ? l10n.gateCheckOut : l10n.gateCheckIn,
        isLoading: _busy,
        onPressed: _submit,
      ),
    );
  }
}
