import 'package:app/app/routes.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/app_text_field.dart';
import 'package:app/features/owner/state/owner_facility_notifier.dart';
import 'package:app/features/owner/ui/facility_form_screen.dart';
import 'package:app/features/parking_lot/data/models/allocation_mode.dart';
import 'package:app/features/parking_lot/data/models/code_name.dart';
import 'package:app/features/parking_lot/data/models/inventory_pool.dart';
import 'package:app/features/parking_lot/data/models/rate_type.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Adds spaces for a vehicle type, or changes an existing pool's capacity
/// and rates.
class PoolFormScreen extends ConsumerStatefulWidget {
  const PoolFormScreen({required this.facilityId, this.poolId, super.key});

  final String facilityId;
  final String? poolId;

  @override
  ConsumerState<PoolFormScreen> createState() => _PoolFormScreenState();
}

class _PoolFormScreenState extends ConsumerState<PoolFormScreen> {
  final _capacity = TextEditingController();
  final _hourly = TextEditingController();
  final _daily = TextEditingController();

  String? _vehicleType;
  bool _filled = false;
  bool _saving = false;
  String? _capacityError;
  String? _hourlyError;
  String? _dailyError;
  String? _formError;
  ApiException? _failure;

  @override
  void dispose() {
    _capacity.dispose();
    _hourly.dispose();
    _daily.dispose();
    super.dispose();
  }

  void _fillFrom(InventoryPool pool) {
    if (_filled) return;
    _filled = true;
    _capacity.text = '${pool.capacity}';
    for (final rate in pool.rates) {
      final controller = switch (rate.rateType) {
        RateType.hourly => _hourly,
        RateType.daily => _daily,
        RateType.unknown => null,
      };
      controller?.text = rate.amount.toStringAsFixed(2);
    }
  }

  Future<void> _save(InventoryPool? pool) async {
    if (_saving) return;
    final l10n = context.l10n;

    // A numbered pool's capacity follows its bays; it is never sent.
    final numbered = pool?.allocationMode == AllocationMode.numbered;
    final capacity = numbered
        ? pool!.capacity
        : int.tryParse(_capacity.text.trim());
    final hourlyText = _hourly.text.trim();
    final dailyText = _daily.text.trim();
    final hourly = hourlyText.isEmpty ? null : parseRate(hourlyText);
    final daily = dailyText.isEmpty ? null : parseRate(dailyText);

    final capacityError = capacity == null || capacity < 1
        ? l10n.poolCapacityInvalid
        : null;
    final hourlyError = hourlyText.isNotEmpty && hourly == null
        ? l10n.poolRateInvalid
        : null;
    final dailyError = dailyText.isNotEmpty && daily == null
        ? l10n.poolRateInvalid
        : null;
    final formError = hourlyText.isEmpty && dailyText.isEmpty
        ? l10n.poolRateRequired
        : null;

    if (capacityError != null ||
        hourlyError != null ||
        dailyError != null ||
        formError != null ||
        (pool == null && _vehicleType == null)) {
      setState(() {
        _capacityError = capacityError;
        _hourlyError = hourlyError;
        _dailyError = dailyError;
        _formError = formError;
        _failure = null;
      });
      return;
    }

    setState(() {
      _saving = true;
      _capacityError = _hourlyError = _dailyError = _formError = null;
      _failure = null;
    });
    final notifier = ref.read(
      ownerFacilityProvider(widget.facilityId).notifier,
    );
    try {
      if (pool == null) {
        await notifier.addPool(
          vehicleType: _vehicleType!,
          capacity: capacity!,
          hourly: hourly,
          daily: daily,
        );
      } else {
        await notifier.updatePool(
          pool.id,
          capacity: capacity!,
          hourly: hourly,
          daily: daily,
        );
      }
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
    final facility = ref
        .watch(ownerFacilityProvider(widget.facilityId))
        .valueOrNull
        ?.facility;
    final options = ref.watch(facilityOptionsProvider).valueOrNull;
    final title = widget.poolId == null
        ? l10n.poolNewTitle
        : l10n.poolEditTitle;

    if (facility == null || options == null) {
      return AppScaffold(
        title: title,
        body: const Column(children: [Gap.lg(), SkeletonCard()]),
      );
    }

    final pool = facility.lot.pools
        .where((pool) => pool.id == widget.poolId)
        .firstOrNull;
    if (pool != null) _fillFrom(pool);

    // A facility has one pool per vehicle type: offer only the unused ones,
    // and show the ones already set up with a way to edit them.
    final configured = facility.lot.pools;
    final used = {for (final p in configured) p.vehicleType.code};
    final available = <CodeName>[
      for (final type in options.vehicleTypes)
        if (!used.contains(type.code)) type,
    ];
    if (pool == null && _vehicleType == null && available.isNotEmpty) {
      _vehicleType = available.first.code;
    }
    final failure = _failure;
    final formError = _formError;
    const money = TextInputType.numberWithOptions(decimal: true);
    final moneyOnly = [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))];

    final configuredList = pool == null && configured.isNotEmpty
        ? <Widget>[
            const Gap.lg(),
            Text(l10n.poolConfiguredTitle, style: context.text.h3),
            const Gap.sm(),
            for (final existing in configured) ...[
              _ConfiguredType(
                pool: existing,
                onEdit: _saving
                    ? null
                    : () => context.pushReplacement(
                        Routes.ownerFacilityPool(
                          widget.facilityId,
                          poolId: existing.id,
                        ),
                      ),
              ),
              const Gap.sm(),
            ],
          ]
        : const <Widget>[];

    if (pool == null && available.isEmpty) {
      return AppScaffold(
        title: title,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap.md(),
            Text(
              // No types at all means the platform has not set any up yet;
              // otherwise every type already has spaces here.
              options.vehicleTypes.isEmpty
                  ? l10n.poolNoTypes
                  : l10n.poolNoneLeft,
              style: context.text.body.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            ...configuredList,
          ],
        ),
      );
    }

    return AppScaffold(
      title: title,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap.md(),
          if (pool == null) ...[
            Text(
              l10n.poolVehicle,
              style: context.text.label.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const Gap.sm(),
            for (final type in available) ...[
              AppCard(
                selected: _vehicleType == type.code,
                onTap: _saving
                    ? null
                    : () => setState(() => _vehicleType = type.code),
                child: Row(
                  children: [
                    Icon(vehicleTypeIcon(type), color: context.colors.primary),
                    const Gap.md(),
                    Expanded(child: Text(type.name, style: context.text.body)),
                    if (_vehicleType == type.code)
                      Icon(Icons.check_circle, color: context.colors.primary),
                  ],
                ),
              ),
              const Gap.sm(),
            ],
            const Gap.sm(),
          ] else ...[
            Text(pool.vehicleType.name, style: context.text.h2),
            const Gap.lg(),
            _BaysCard(
              pool: pool,
              onManage: _saving
                  ? null
                  : () => context.push(
                      Routes.ownerPoolSpaces(widget.facilityId, pool.id),
                    ),
            ),
            const Gap.md(),
          ],
          if (pool?.allocationMode == AllocationMode.numbered)
            Text(
              l10n.poolCapacityFromBays,
              style: context.text.bodySmall.copyWith(
                color: context.colors.textSecondary,
              ),
            )
          else
            AppTextField(
              label: l10n.poolCapacity,
              controller: _capacity,
              enabled: !_saving,
              errorText: _capacityError,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
            ),
          const Gap.lg(),
          Text(l10n.lotRates, style: context.text.h3),
          const Gap.xs(),
          Text(
            l10n.poolRateHelp,
            style: context.text.bodySmall.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const Gap.md(),
          AppTextField(
            label: l10n.poolHourly,
            controller: _hourly,
            enabled: !_saving,
            errorText: _hourlyError,
            keyboardType: money,
            inputFormatters: moneyOnly,
            textInputAction: TextInputAction.next,
          ),
          const Gap.sm(),
          AppTextField(
            label: l10n.poolDaily,
            controller: _daily,
            enabled: !_saving,
            errorText: _dailyError,
            keyboardType: money,
            inputFormatters: moneyOnly,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(pool),
          ),
          if (formError != null) ...[
            const Gap.sm(),
            AppBanner(tone: StatusTone.danger, message: formError),
          ],
          if (failure != null) ...[
            const Gap.sm(),
            AppBanner(
              tone: StatusTone.danger,
              message: facilityFailureText(l10n, failure),
            ),
          ],
          ...configuredList,
        ],
      ),
      bottom: PrimaryButton(
        label: l10n.facilitySave,
        isLoading: _saving,
        onPressed: () => _save(pool),
      ),
    );
  }
}

/// An icon for a vehicle type, from its code or name (2, 4, 6 or 8 wheels).
IconData vehicleTypeIcon(CodeName type) {
  final text = '${type.code} ${type.name}'.toLowerCase();
  if (RegExp(r'\b(2|two)[-_ ]?wheel|bike|scooter|motorcycle').hasMatch(text)) {
    return Icons.two_wheeler;
  }
  if (RegExp(r'\b(8|eight)[-_ ]?wheel|truck|trailer').hasMatch(text)) {
    return Icons.local_shipping;
  }
  if (RegExp(r'\b(6|six)[-_ ]?wheel|bus|van|tempo').hasMatch(text)) {
    return Icons.airport_shuttle;
  }
  return Icons.directions_car;
}

/// A vehicle type this facility already has spaces for, with its capacity.
class _ConfiguredType extends StatelessWidget {
  const _ConfiguredType({required this.pool, required this.onEdit});

  final InventoryPool pool;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppCard(
      child: Row(
        children: [
          Icon(
            vehicleTypeIcon(pool.vehicleType),
            color: context.colors.textSecondary,
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pool.vehicleType.name, style: context.text.body),
                Text(
                  l10n.poolConfiguredCapacity(pool.capacity),
                  style: context.text.bodySmall.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onEdit, child: Text(l10n.poolEdit)),
        ],
      ),
    );
  }
}

/// How this vehicle type hands out spaces, and the way to its bays.
class _BaysCard extends StatelessWidget {
  const _BaysCard({required this.pool, required this.onManage});

  final InventoryPool pool;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final numbered = pool.allocationMode == AllocationMode.numbered;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.poolBaysTitle, style: context.text.h3),
          const Gap.xs(),
          Text(
            numbered
                ? l10n.poolBaysNumbered(pool.capacity)
                : l10n.poolBaysPooled,
            style: context.text.bodySmall.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const Gap.sm(),
          SecondaryButton(
            label: numbered ? l10n.poolBaysManage : l10n.poolBaysUseNumbered,
            onPressed: onManage,
          ),
        ],
      ),
    );
  }
}
