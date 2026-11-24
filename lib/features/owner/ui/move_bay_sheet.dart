import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/providers.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_list_row.dart';
import 'package:app/features/booking/data/booking_repository.dart';
import 'package:app/features/booking/data/models/bay_option.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/booking/data/models/booking_window_request.dart';
import 'package:app/features/booking/ui/bay_picker.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bays free for this booking's time, other than its own.
final _freeBaysProvider = FutureProvider.autoDispose
    .family<List<BayOption>, Booking>((ref, booking) async {
      final availability = await ref
          .watch(bookingRepositoryProvider)
          .availability(
            BookingWindowRequest(
              parkingLotId: booking.parkingLot.id,
              vehicleType: booking.vehicleType,
              startAt: booking.startAt,
              endAt: booking.endAt,
            ),
          );
      return [
        for (final bay in availability.bays ?? const <BayOption>[])
          if (bay.available && bay.label != booking.spaceLabel) bay,
      ];
    });

/// Lets the owner move a booking to another free bay (a bay broke, or the
/// customer needs an accessible one). Returns the new bay's label, or null
/// when nothing changed.
Future<String?> showMoveBaySheet(BuildContext context, Booking booking) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _MoveBaySheet(booking: booking),
    );

class _MoveBaySheet extends ConsumerStatefulWidget {
  const _MoveBaySheet({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_MoveBaySheet> createState() => _MoveBaySheetState();
}

class _MoveBaySheetState extends ConsumerState<_MoveBaySheet> {
  bool _busy = false;
  String? _error;

  Future<void> _move(BayOption bay) async {
    if (_busy) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/owner/bookings/${widget.booking.id}/move-bay',
            body: {'parking_space_id': bay.id},
          );
      if (mounted) Navigator.of(context).pop(bay.label);
    } on ApiException catch (failure) {
      if (!mounted) return;
      ref.invalidate(_freeBaysProvider(widget.booking));
      setState(() {
        _busy = false;
        _error = failure.code == ApiErrorCode.parkingSpaceUnavailable
            ? l10n.errBayUnavailable
            : l10n.describe(failure);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final bays = ref.watch(_freeBaysProvider(widget.booking));
    final error = _error;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSize.screenPadding,
          0,
          AppSize.screenPadding,
          AppSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.bayMoveTitle, style: text.h2),
            const Gap.md(),
            if (error != null) ...[
              Text(
                error,
                style: text.bodySmall.copyWith(color: colors.danger.solid),
              ),
              const Gap.md(),
            ],
            switch (bays) {
              AsyncData(:final value) when value.isEmpty => Text(
                l10n.bayMoveNone,
                style: text.body.copyWith(color: colors.textSecondary),
              ),
              AsyncData(:final value) => ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: SingleChildScrollView(
                  child: AppListGroup(
                    children: [
                      for (final bay in value)
                        AppListRow(
                          icon: bay.features.isEmpty
                              ? Icons.local_parking_outlined
                              : bayFeatureIcon(bay.features.first),
                          title: bay.label,
                          subtitle: bay.features.isEmpty
                              ? null
                              : bay.features
                                    .map((f) => bayFeatureName(context, f))
                                    .join(', '),
                          onTap: _busy ? null : () => _move(bay),
                        ),
                    ],
                  ),
                ),
              ),
              AsyncError(:final error) => Text(
                l10n.describe(
                  error is ApiException
                      ? error
                      : const ApiException(code: ApiErrorCode.unknown),
                ),
                style: text.bodySmall.copyWith(color: colors.danger.solid),
              ),
              _ => const LinearProgressIndicator(),
            },
          ],
        ),
      ),
    );
  }
}
