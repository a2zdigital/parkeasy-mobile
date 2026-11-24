import 'package:app/core/api/api_exception.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/features/booking/data/booking_repository.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/booking/state/booking_details_notifier.dart';
import 'package:app/features/booking/state/bookings_notifier.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks for a rating right after checking out. "Maybe later" closes it; the
/// booking page keeps its rating card, and this sheet is not shown again.
Future<void> showRatingSheet(BuildContext context, Booking booking) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => RatingSheet(booking: booking),
    );

class RatingSheet extends ConsumerStatefulWidget {
  const RatingSheet({required this.booking, super.key});

  final Booking booking;

  @override
  ConsumerState<RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends ConsumerState<RatingSheet> {
  final _feedback = TextEditingController();
  int _score = 0;
  bool _sending = false;
  ApiException? _failure;

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_score == 0 || _sending) return;
    setState(() {
      _sending = true;
      _failure = null;
    });
    try {
      final text = _feedback.text.trim();
      await ref
          .read(bookingRepositoryProvider)
          .rate(widget.booking.id, _score, text.isEmpty ? null : text);
      ref.invalidate(bookingsProvider);
      await ref
          .read(bookingDetailsProvider(widget.booking.id).notifier)
          .refresh();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.ratingThanks)),
      );
    } on ApiException catch (failure) {
      if (mounted) {
        setState(() {
          _sending = false;
          _failure = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final failure = _failure;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpace.lg,
        right: AppSpace.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpace.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.ratingSheetTitle, style: text.h2),
          const Gap.xs(),
          Text(l10n.ratingSheetMessage, style: text.body),
          const Gap.xs(),
          Text(
            widget.booking.parkingLot.name,
            style: text.bodySmall.copyWith(color: colors.textSecondary),
          ),
          const Gap.md(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var star = 1; star <= 5; star++)
                IconButton(
                  key: ValueKey('rating-star-$star'),
                  tooltip: l10n.ratingStars(star),
                  iconSize: 40,
                  onPressed: _sending
                      ? null
                      : () => setState(() => _score = star),
                  icon: Icon(
                    star <= _score
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: star <= _score
                        ? Colors.amber.shade700
                        : colors.textSecondary,
                  ),
                ),
            ],
          ),
          const Gap.md(),
          TextField(
            key: const ValueKey('rating-feedback'),
            controller: _feedback,
            enabled: !_sending,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: l10n.ratingFeedbackLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          if (failure != null) ...[
            const Gap.sm(),
            Text(
              l10n.describe(failure),
              style: text.bodySmall.copyWith(color: colors.danger.solid),
            ),
          ],
          const Gap.md(),
          PrimaryButton(
            label: l10n.ratingSubmit,
            isLoading: _sending,
            onPressed: _score == 0 ? null : _submit,
          ),
          const Gap.sm(),
          TextButton(
            onPressed: _sending ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.ratingMaybeLater),
          ),
        ],
      ),
    );
  }
}
