import 'package:app/core/api/api_exception.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/time/facility_time.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/features/owner/data/models/operating_hour_input.dart';
import 'package:app/features/owner/state/owner_facility_notifier.dart';
import 'package:app/features/owner/ui/facility_form_screen.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// One day being edited. Times are `HH:mm`; `24:00` is the end of the day.
class _Day {
  _Day({required this.isClosed, required this.opens, required this.closes});

  bool isClosed;
  String opens;
  String closes;

  static int _minutes(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  bool get isValid => isClosed || _minutes(closes) > _minutes(opens);
}

/// Sets the opening hours for all seven days at once, which is what the
/// API stores.
class HoursFormScreen extends ConsumerStatefulWidget {
  const HoursFormScreen({required this.facilityId, super.key});

  final String facilityId;

  @override
  ConsumerState<HoursFormScreen> createState() => _HoursFormScreenState();
}

class _HoursFormScreenState extends ConsumerState<HoursFormScreen> {
  List<_Day>? _days;
  bool _saving = false;
  bool _invalid = false;
  ApiException? _failure;

  List<_Day> _initial() {
    final existing =
        ref
            .read(ownerFacilityProvider(widget.facilityId))
            .valueOrNull
            ?.facility
            .lot
            .operatingHours ??
        const [];
    return [
      for (var day = 1; day <= 7; day++)
        () {
          final saved = existing
              .where((hour) => hour.dayOfWeek == day)
              .firstOrNull;
          return _Day(
            isClosed: saved?.isClosed ?? false,
            opens: (saved?.opensAt ?? '00:00').substring(0, 5),
            closes: (saved?.closesAt ?? '24:00').substring(0, 5),
          );
        }(),
    ];
  }

  Future<void> _pick(_Day day, {required bool opening}) async {
    final current = opening ? day.opens : day.closes;
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]) % 24,
        minute: int.parse(parts[1]),
      ),
    );
    if (picked == null) return;

    String two(int value) => value.toString().padLeft(2, '0');
    var value = '${two(picked.hour)}:${two(picked.minute)}';
    // Midnight as a closing time means the end of the day.
    if (!opening && value == '00:00') value = '24:00';
    setState(() {
      if (opening) {
        day.opens = value;
      } else {
        day.closes = value;
      }
      _invalid = false;
    });
  }

  Future<void> _save(List<_Day> days) async {
    if (_saving) return;
    if (days.any((day) => !day.isValid)) {
      setState(() => _invalid = true);
      return;
    }

    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(ownerFacilityProvider(widget.facilityId).notifier)
          .setHours([
            for (final (index, day) in days.indexed)
              OperatingHourInput(
                dayOfWeek: index + 1,
                isClosed: day.isClosed,
                opensAt: day.isClosed ? null : day.opens,
                closesAt: day.isClosed ? null : day.closes,
              ),
          ]);
      if (mounted) context.pop();
    } on ApiException catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
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
    final locale = Localizations.localeOf(context).toLanguageTag();
    final days = _days ??= _initial();
    final failure = _failure;

    return AppScaffold(
      title: l10n.hoursTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap.md(),
          SecondaryButton(
            label: l10n.hoursOpenAllDay,
            onPressed: _saving
                ? null
                : () => setState(() {
                    for (final day in days) {
                      day
                        ..isClosed = false
                        ..opens = '00:00'
                        ..closes = '24:00';
                    }
                    _invalid = false;
                  }),
          ),
          const Gap.md(),
          for (final (index, day) in days.indexed) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          FacilityTime.weekday(index + 1, locale),
                          style: text.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        l10n.hoursClosedDay,
                        style: text.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      Switch(
                        value: day.isClosed,
                        activeTrackColor: colors.primary,
                        onChanged: _saving
                            ? null
                            : (closed) => setState(() {
                                day.isClosed = closed;
                                _invalid = false;
                              }),
                      ),
                    ],
                  ),
                  if (!day.isClosed)
                    Row(
                      children: [
                        Expanded(
                          child: TextAction(
                            label:
                                '${l10n.hoursOpens} ${FacilityTime.clock(day.opens, locale)}',
                            onPressed: _saving
                                ? null
                                : () => _pick(day, opening: true),
                          ),
                        ),
                        Expanded(
                          child: TextAction(
                            label:
                                '${l10n.hoursCloses} ${FacilityTime.clock(day.closes, locale)}',
                            onPressed: _saving
                                ? null
                                : () => _pick(day, opening: false),
                          ),
                        ),
                      ],
                    ),
                  if (_invalid && !day.isValid)
                    Text(
                      l10n.hoursInvalid,
                      style: text.bodySmall.copyWith(
                        color: colors.danger.solid,
                      ),
                    ),
                ],
              ),
            ),
            const Gap.sm(),
          ],
          if (failure != null)
            AppBanner(
              tone: StatusTone.danger,
              message: facilityFailureText(l10n, failure),
            ),
          const Gap.lg(),
        ],
      ),
      bottom: PrimaryButton(
        label: l10n.facilitySave,
        isLoading: _saving,
        onPressed: () => _save(days),
      ),
    );
  }
}
