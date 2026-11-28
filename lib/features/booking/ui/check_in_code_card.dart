import 'dart:async';

import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/features/booking/data/booking_repository.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// The code the customer shows at the gate: a QR code the facility scans,
/// and the code as text, in two halves, to read out or type in.
///
/// With a [bookingId] the QR code holds a signed pass from the API that
/// changes every minute, so a screenshot stops working; it is fetched again
/// before it expires. Until a pass arrives, or if there is none, the QR code
/// holds the plain code, which the gate also accepts.
class CheckInCodeCard extends ConsumerStatefulWidget {
  const CheckInCodeCard({
    required this.code,
    this.bookingId,
    this.checkOut = false,
    super.key,
  });

  final String code;
  final String? bookingId;

  /// The code for leaving (while parked) rather than for arriving.
  final bool checkOut;

  /// Side of the QR code. Large enough to scan from an arm's length.
  static const double qrSize = 184;

  /// How often a fresh pass is fetched; passes work for about two minutes.
  static const Duration refreshEvery = Duration(seconds: 45);

  /// "7KQ3MZ8D" as "7KQ3 MZ8D".
  static String readable(String code) =>
      code.length == 8 ? '${code.substring(0, 4)} ${code.substring(4)}' : code;

  @override
  ConsumerState<CheckInCodeCard> createState() => _CheckInCodeCardState();
}

class _CheckInCodeCardState extends ConsumerState<CheckInCodeCard> {
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    final id = widget.bookingId;
    if (id != null) {
      _refresh = Timer.periodic(
        CheckInCodeCard.refreshEvery,
        (_) => ref.invalidate(
          widget.checkOut ? checkOutPassProvider(id) : checkInPassProvider(id),
        ),
      );
    }
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final code = widget.code;
    final id = widget.bookingId;
    final pass = id == null
        ? null
        : ref
              .watch(
                widget.checkOut
                    ? checkOutPassProvider(id)
                    : checkInPassProvider(id),
              )
              .valueOrNull;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.checkOut ? l10n.checkOutCodeTitle : l10n.checkInCodeTitle,
            style: text.label.copyWith(color: colors.textSecondary),
          ),
          const Gap.sm(),
          Center(
            // Scanners need dark modules on a light background.
            child: QrImageView(
              data: pass?.token ?? code,
              size: CheckInCodeCard.qrSize,
              backgroundColor: Colors.white,
              semanticsLabel: l10n.checkInQrSemantics,
            ),
          ),
          const Gap.sm(),
          Center(
            child: Semantics(
              label: l10n.checkInCodeSemantics(code.split('').join(' ')),
              excludeSemantics: true,
              child: SelectableText(
                CheckInCodeCard.readable(code),
                style: text.h1.copyWith(
                  letterSpacing: AppSpace.xs,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const Gap.xs(),
          Text(
            widget.checkOut
                ? l10n.checkOutCodeHint
                : (pass == null ? l10n.checkInCodeHint : l10n.checkInPassHint),
            style: text.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
