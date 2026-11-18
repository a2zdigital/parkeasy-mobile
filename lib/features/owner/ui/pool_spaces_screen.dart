import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/app_text_field.dart';
import 'package:app/core/widgets/confirm_dialog.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/features/booking/data/models/bay_option.dart';
import 'package:app/features/booking/ui/bay_picker.dart';
import 'package:app/features/owner/data/models/parking_space.dart';
import 'package:app/features/owner/data/owner_repository.dart';
import 'package:app/features/owner/state/owner_facility_notifier.dart';
import 'package:app/features/owner/ui/facility_form_screen.dart';
import 'package:app/features/parking_lot/data/models/allocation_mode.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A pool's numbered bays, by pool ID.
final poolSpacesProvider = FutureProvider.autoDispose
    .family<List<ParkingSpace>, String>(
      (ref, poolId) => ref.watch(ownerRepositoryProvider).spaces(poolId),
    );

/// Bay labels the API accepts (`ParkingSpaceLabel`).
final _labelPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9 \-/.]{0,19}$');

/// What the owner typed as new bays: a numbered range, a comma-separated
/// list, or both. Returns null with [error] set when something is invalid.
({List<String> labels, String? error}) parseBayInput(
  AppLocalizations l10n, {
  required String prefix,
  required String from,
  required String to,
  required String list,
}) {
  final labels = <String>[];
  final fromText = from.trim();
  final toText = to.trim();
  if (fromText.isNotEmpty || toText.isNotEmpty) {
    final first = int.tryParse(fromText);
    final last = int.tryParse(toText);
    if (first == null || last == null || first > last || last - first >= 200) {
      return (labels: const [], error: l10n.baysRangeInvalid);
    }
    // "01" to "20" keeps two digits: 01, 02, ... 20.
    final width = fromText.length;
    for (var n = first; n <= last; n++) {
      labels.add('${prefix.trim()}${'$n'.padLeft(width, '0')}');
    }
  }
  labels.addAll(
    list.split(',').map((label) => label.trim()).where((l) => l.isNotEmpty),
  );

  if (labels.isEmpty) return (labels: const [], error: l10n.baysEmptyInput);
  if (labels.any((label) => !_labelPattern.hasMatch(label))) {
    return (labels: const [], error: l10n.baysInvalid);
  }
  final seen = <String>{};
  final unique = [
    for (final label in labels)
      if (seen.add(label.toLowerCase())) label,
  ];
  return (labels: unique, error: null);
}

/// Numbered bays for one vehicle type: switching to them, adding bays, and
/// taking bays in and out of use. Every change goes to the API and the
/// screen then shows what the server holds.
class PoolSpacesScreen extends ConsumerStatefulWidget {
  const PoolSpacesScreen({
    required this.facilityId,
    required this.poolId,
    super.key,
  });

  final String facilityId;
  final String poolId;

  @override
  ConsumerState<PoolSpacesScreen> createState() => _PoolSpacesScreenState();
}

class _PoolSpacesScreenState extends ConsumerState<PoolSpacesScreen> {
  final _prefix = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _list = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _prefix.dispose();
    _from.dispose();
    _to.dispose();
    _list.dispose();
    super.dispose();
  }

  OwnerRepository get _repository => ref.read(ownerRepositoryProvider);

  String _failureText(ApiException failure) {
    final l10n = context.l10n;
    return switch (failure.code) {
      ApiErrorCode.parkingSpaceInUse => l10n.errParkingSpaceInUse,
      _ => failure.message ?? facilityFailureText(l10n, failure),
    };
  }

  Future<void> _run(
    Future<void> Function() change, {
    bool modeChanged = false,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await change();
      if (modeChanged) ref.invalidate(ownerFacilityProvider(widget.facilityId));
      ref.invalidate(poolSpacesProvider(widget.poolId));
    } on ApiException catch (failure) {
      if (mounted) setState(() => _error = _failureText(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<String>? _readInput() {
    final parsed = parseBayInput(
      context.l10n,
      prefix: _prefix.text,
      from: _from.text,
      to: _to.text,
      list: _list.text,
    );
    if (parsed.error != null) {
      setState(() => _error = parsed.error);
      return null;
    }
    return parsed.labels;
  }

  void _clearInput() {
    _prefix.clear();
    _from.clear();
    _to.clear();
    _list.clear();
  }

  Future<void> _add({required bool switching}) async {
    final labels = _readInput();
    if (labels == null) return;
    await _run(() async {
      if (switching) {
        await _repository.setAllocationMode(
          widget.poolId,
          AllocationMode.numbered,
          labels: labels,
        );
      } else {
        await _repository.addSpaces(widget.poolId, labels);
      }
      _clearInput();
    }, modeChanged: true);
  }

  Future<void> _stopNumbering() async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.baysSwitchOffTitle,
      body: l10n.baysSwitchOffBody,
      confirmLabel: l10n.baysSwitchOff,
      cancelLabel: l10n.baysKeep,
    );
    if (!confirmed) return;
    await _run(
      () => _repository.setAllocationMode(widget.poolId, AllocationMode.pooled),
      modeChanged: true,
    );
  }

  Future<void> _delete(ParkingSpace space) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.baysDeleteTitle,
      body: l10n.baysDeleteBody,
      confirmLabel: l10n.baysDeleteConfirm,
      cancelLabel: l10n.baysCancel,
      isDestructive: true,
    );
    if (!confirmed) return;
    await _run(
      () => _repository.deleteSpace(widget.poolId, space.id),
      modeChanged: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final facility = ref
        .watch(ownerFacilityProvider(widget.facilityId))
        .valueOrNull
        ?.facility;
    final pool = facility?.lot.pools
        .where((pool) => pool.id == widget.poolId)
        .firstOrNull;

    if (pool == null) {
      return AppScaffold(
        title: l10n.baysTitle,
        body: const Column(children: [Gap.lg(), SkeletonCard()]),
      );
    }

    final numbered = pool.allocationMode == AllocationMode.numbered;
    final spaces = ref.watch(poolSpacesProvider(widget.poolId));
    final error = _error;

    return AppScaffold(
      title: l10n.baysTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap.md(),
          Text(pool.vehicleType.name, style: text.h2),
          const Gap.xs(),
          Text(
            l10n.baysIntro,
            style: text.bodySmall.copyWith(color: colors.textSecondary),
          ),
          const Gap.lg(),
          _BayInput(
            prefix: _prefix,
            from: _from,
            to: _to,
            list: _list,
            enabled: !_busy,
          ),
          if (error != null) ...[
            const Gap.sm(),
            AppBanner(tone: StatusTone.danger, message: error),
          ],
          const Gap.md(),
          if (numbered)
            SecondaryButton(
              label: l10n.baysAdd,
              isLoading: _busy,
              onPressed: () => _add(switching: false),
            )
          else
            PrimaryButton(
              label: l10n.baysSwitchOn,
              isLoading: _busy,
              onPressed: () => _add(switching: true),
            ),
          const Gap.lg(),
          spaces.when(
            loading: () => const SkeletonCard(),
            error: (failure, _) => ErrorState(
              failure: failure is ApiException
                  ? failure
                  : const ApiException(code: ApiErrorCode.unknown),
              onRetry: () => ref.invalidate(poolSpacesProvider(widget.poolId)),
            ),
            data: (spaces) => spaces.isEmpty
                ? const SizedBox.shrink()
                : _BayList(
                    spaces: spaces,
                    enabled: numbered && !_busy,
                    onToggle: (space, active) => _run(
                      () => _repository.setSpaceActive(
                        widget.poolId,
                        space.id,
                        active,
                      ),
                      modeChanged: true,
                    ),
                    onDelete: _delete,
                    onFeatures: (space, features) => _run(
                      () => _repository.setSpaceFeatures(
                        widget.poolId,
                        space.id,
                        features,
                      ),
                    ),
                  ),
          ),
          if (numbered) ...[
            const Gap.lg(),
            TextAction(
              label: l10n.baysSwitchOff,
              onPressed: _busy ? null : _stopNumbering,
            ),
          ],
          const Gap.xl(),
        ],
      ),
    );
  }
}

class _BayInput extends StatelessWidget {
  const _BayInput({
    required this.prefix,
    required this.from,
    required this.to,
    required this.list,
    required this.enabled,
  });

  final TextEditingController prefix;
  final TextEditingController from;
  final TextEditingController to;
  final TextEditingController list;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final digits = [FilteringTextInputFormatter.digitsOnly];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: l10n.baysRangePrefix,
          controller: prefix,
          enabled: enabled,
          helperText: l10n.baysRangeHelp,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
        ),
        const Gap.sm(),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: l10n.baysRangeFrom,
                controller: from,
                enabled: enabled,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                textInputAction: TextInputAction.next,
              ),
            ),
            const Gap.sm(),
            Expanded(
              child: AppTextField(
                label: l10n.baysRangeTo,
                controller: to,
                enabled: enabled,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const Gap.sm(),
        AppTextField(
          label: l10n.baysLabels,
          controller: list,
          enabled: enabled,
          helperText: l10n.baysLabelsHelp,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}

class _BayList extends StatelessWidget {
  const _BayList({
    required this.spaces,
    required this.enabled,
    required this.onToggle,
    required this.onDelete,
    required this.onFeatures,
  });

  final List<ParkingSpace> spaces;
  final bool enabled;
  final void Function(ParkingSpace space, bool active) onToggle;
  final void Function(ParkingSpace space) onDelete;
  final void Function(ParkingSpace space, List<String> features) onFeatures;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final active = spaces.where((space) => space.isActive).length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.baysInUse(active, spaces.length),
            style: text.label.copyWith(color: colors.textSecondary),
          ),
          for (final space in spaces)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(space.label, style: text.body),
                      // Bay types: tap to switch each on or off.
                      Wrap(
                        spacing: AppSpace.xs,
                        children: [
                          for (final feature in BayFeatures.all)
                            FilterChip(
                              visualDensity: VisualDensity.compact,
                              avatar: Icon(
                                bayFeatureIcon(feature),
                                size: AppSize.iconSmall,
                              ),
                              label: Text(bayFeatureName(context, feature)),
                              selected: space.features.contains(feature),
                              onSelected: enabled
                                  ? (on) => onFeatures(space, [
                                      for (final f in BayFeatures.all)
                                        if (f == feature
                                            ? on
                                            : space.features.contains(f))
                                          f,
                                    ])
                                  : null,
                            ),
                        ],
                      ),
                      if (!space.isActive)
                        Text(
                          l10n.baysInactive,
                          style: text.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Semantics(
                  label: space.isActive
                      ? l10n.baysDeactivate(space.label)
                      : l10n.baysActivate(space.label),
                  child: Switch(
                    value: space.isActive,
                    onChanged: enabled
                        ? (value) => onToggle(space, value)
                        : null,
                  ),
                ),
                IconButton(
                  tooltip: l10n.baysDelete(space.label),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: enabled ? () => onDelete(space) : null,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
