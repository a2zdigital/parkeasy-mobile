import 'package:app/core/api/api_exception.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/time/facility_time.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_list_row.dart';
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
          const Gap.lg(),
          // One card for the week: each day says what it is now, the switch
          // opens or closes it, and an open day shows its two times.
          AppListGroup(
            children: [
              for (final (index, day) in days.indexed)
                _DayRow(
                  weekday: FacilityTime.weekday(index + 1, locale),
                  summary: day.isClosed
                      ? l10n.hoursClosedDay
                      : day.opens == '00:00' && day.closes == '24:00'
                      ? l10n.lotOpen24
                      : l10n.lotHoursRange(
                          FacilityTime.clock(day.opens, locale),
                          FacilityTime.clock(day.closes, locale),
                        ),
                  isOpen: !day.isClosed,
                  opensLabel:
                      '${l10n.hoursOpens} ${FacilityTime.clock(day.opens, locale)}',
                  // 24:00 is the end of the day, not "12:00 AM".
                  closesLabel: day.closes == '24:00'
                      ? '${l10n.hoursCloses} ${l10n.hoursMidnight}'
                      : '${l10n.hoursCloses} ${FacilityTime.clock(day.closes, locale)}',
                  error: _invalid && !day.isValid ? l10n.hoursInvalid : null,
                  enabled: !_saving,
                  onOpenChanged: (open) => setState(() {
                    day.isClosed = !open;
                    _invalid = false;
                  }),
                  onPickOpens: () => _pick(day, opening: true),
                  onPickCloses: () => _pick(day, opening: false),
                ),
            ],
          ),
          const Gap.md(),
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

/// One day of the week inside the hours card.
class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.weekday,
    required this.summary,
    required this.isOpen,
    required this.opensLabel,
    required this.closesLabel,
    required this.error,
    required this.enabled,
    required this.onOpenChanged,
    required this.onPickOpens,
    required this.onPickCloses,
  });

  final String weekday;
  final String summary;
  final bool isOpen;
  final String opensLabel;
  final String closesLabel;
  final String? error;
  final bool enabled;
  final ValueChanged<bool> onOpenChanged;
  final VoidCallback onPickOpens;
  final VoidCallback onPickCloses;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    final error = this.error;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.md,
        AppSpace.sm,
        AppSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weekday,
                      style: text.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      summary,
                      style: text.bodySmall.copyWith(
                        color: isOpen
                            ? colors.textSecondary
                            : colors.danger.strong,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                label: '$weekday open',
                child: Switch(
                  value: isOpen,
                  activeTrackColor: colors.primary,
                  onChanged: enabled ? onOpenChanged : null,
                ),
              ),
            ],
          ),
          if (isOpen) ...[
            const Gap.sm(),
            Row(
              children: [
                Expanded(
                  child: _TimeButton(
                    label: opensLabel,
                    onPressed: enabled ? onPickOpens : null,
                  ),
                ),
                const Gap.sm(),
                Expanded(
                  child: _TimeButton(
                    label: closesLabel,
                    onPressed: enabled ? onPickCloses : null,
                  ),
                ),
                const Gap.sm(),
              ],
            ),
          ],
          if (error != null) ...[
            const Gap.xs(),
            Text(
              error,
              style: text.bodySmall.copyWith(color: colors.danger.solid),
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact time chip: shows the time and opens the picker.
class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        minimumSize: const Size(0, AppSize.touchTarget),
        foregroundColor: colors.textPrimary,
        side: BorderSide(color: colors.border),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.controlAll),
        textStyle: context.text.bodySmall.copyWith(fontWeight: FontWeight.w600),
      ),
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
    );
  }
}
