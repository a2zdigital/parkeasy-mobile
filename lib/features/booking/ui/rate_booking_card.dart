import 'package:app/core/api/api_exception.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/features/booking/data/booking_repository.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/booking/state/booking_details_notifier.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stars, filled up to [score]. Read as "4 out of 5".
class RatingStars extends StatelessWidget {
  const RatingStars({required this.score, this.size = 20, super.key});

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.ratingOutOfFive(score),
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var star = 1; star <= 5; star++)
            Icon(
              star <= score ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: star <= score
                  ? context.colors.warning.solid
                  : context.colors.textSecondary,
            ),
        ],
      ),
    ),
  );
}

/// After a completed booking: the customer's rating, or a way to give one.
class RateBookingCard extends ConsumerStatefulWidget {
  const RateBookingCard({required this.booking, super.key});

  final Booking booking;

  @override
  ConsumerState<RateBookingCard> createState() => _RateBookingCardState();
}

class _RateBookingCardState extends ConsumerState<RateBookingCard> {
  final _comment = TextEditingController();
  int _score = 0;
  bool _sending = false;
  ApiException? _failure;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_score == 0 || _sending) return;
    setState(() {
      _sending = true;
      _failure = null;
    });
    try {
      final comment = _comment.text.trim();
      await ref
          .read(bookingRepositoryProvider)
          .rate(widget.booking.id, _score, comment.isEmpty ? null : comment);
      await ref
          .read(bookingDetailsProvider(widget.booking.id).notifier)
          .refresh();
    } on ApiException catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final rated = widget.booking.myRating;
    final failure = _failure;

    if (rated != null) {
      return AppCard(
        child: Row(
          children: [
            Expanded(child: Text(l10n.ratingYours, style: text.body)),
            RatingStars(score: rated),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.ratingPrompt, style: text.h3),
          const Gap.xs(),
          Text(
            l10n.ratingPromptBody,
            style: text.bodySmall.copyWith(color: colors.textSecondary),
          ),
          const Gap.sm(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var star = 1; star <= 5; star++)
                IconButton(
                  tooltip: l10n.ratingOutOfFive(star),
                  iconSize: 36,
                  icon: Icon(
                    star <= _score
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: star <= _score
                        ? colors.warning.solid
                        : colors.textSecondary,
                  ),
                  onPressed: _sending
                      ? null
                      : () => setState(() => _score = star),
                ),
            ],
          ),
          TextField(
            controller: _comment,
            enabled: !_sending,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.ratingComment),
          ),
          if (failure != null) ...[
            AppBanner(
              tone: StatusTone.danger,
              // 409: already rated, or the booking is not completed yet.
              message: failure.status == 409
                  ? l10n.ratingNotAllowed
                  : l10n.describe(failure),
            ),
            const Gap.sm(),
          ],
          SecondaryButton(
            label: l10n.ratingSend,
            isLoading: _sending,
            onPressed: _score == 0 ? null : _send,
          ),
        ],
      ),
    );
  }
}
