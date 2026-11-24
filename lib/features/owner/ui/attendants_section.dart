import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/providers.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_list_row.dart';
import 'package:app/core/widgets/app_text_field.dart';
import 'package:app/core/widgets/confirm_dialog.dart';
import 'package:app/features/auth/state/phone_number.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One gate attendant of a facility, as the owner sees them.
class FacilityAttendantInfo {
  const FacilityAttendantInfo({
    required this.id,
    required this.name,
    required this.phoneMasked,
  });

  final String id;
  final String? name;
  final String phoneMasked;
}

final attendantsProvider = FutureProvider.autoDispose
    .family<List<FacilityAttendantInfo>, String>((ref, facilityId) async {
      final api = ref.watch(apiClientProvider);
      final data = (await api.get(
        '/owner/parking-lots/$facilityId/attendants',
      ))['data'];
      if (data is! List) throw const ApiException(code: ApiErrorCode.unknown);
      return [
        for (final item in data)
          if (item case {
            'id': final String id,
            'phone_masked': final String phone,
          })
            FacilityAttendantInfo(
              id: id,
              name: item['name'] as String?,
              phoneMasked: phone,
            ),
      ];
    });

/// Gate attendants for an approved facility: people who can check vehicles
/// in and out here and do nothing else. Added by mobile number.
class AttendantsSection extends ConsumerStatefulWidget {
  const AttendantsSection({required this.facilityId, super.key});

  final String facilityId;

  @override
  ConsumerState<AttendantsSection> createState() => _AttendantsSectionState();
}

class _AttendantsSectionState extends ConsumerState<AttendantsSection> {
  final _phone = TextEditingController();
  bool _adding = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> _add() async {
    if (_busy) return;
    final l10n = context.l10n;
    final phone = PhoneNumber.toE164(_phone.text);
    if (phone == null) {
      setState(() => _error = l10n.phoneInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.post(
        '/owner/parking-lots/${widget.facilityId}/attendants',
        body: {'phone': phone},
      );
      ref.invalidate(attendantsProvider(widget.facilityId));
      _phone.clear();
      if (mounted) {
        setState(() {
          _busy = false;
          _adding = false;
        });
      }
    } on ApiException catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.code == ApiErrorCode.attendantNotAllowed
            ? l10n.attendantsSelf
            : l10n.describe(failure);
      });
    }
  }

  Future<void> _remove(FacilityAttendantInfo attendant) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.attendantsRemoveTitle,
      body: l10n.attendantsRemoveBody,
      confirmLabel: l10n.attendantsRemove,
      cancelLabel: l10n.actionCancel,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _error = null);
    try {
      await _api.delete(
        '/owner/parking-lots/${widget.facilityId}/attendants/${attendant.id}',
      );
      ref.invalidate(attendantsProvider(widget.facilityId));
    } on ApiException catch (failure) {
      if (mounted) setState(() => _error = l10n.describe(failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final attendants = ref.watch(attendantsProvider(widget.facilityId));
    final error = _error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: SectionHeader(l10n.attendantsTitle)),
            if (!_adding)
              TextAction(
                label: l10n.attendantsAdd,
                onPressed: () => setState(() => _adding = true),
              ),
          ],
        ),
        Text(
          l10n.attendantsHint,
          style: text.bodySmall.copyWith(color: colors.textSecondary),
        ),
        const Gap.md(),
        if (_adding) ...[
          AppTextField(
            label: l10n.attendantsPhone,
            controller: _phone,
            enabled: !_busy,
            autofocus: true,
            keyboardType: TextInputType.phone,
            prefixText: '${PhoneNumber.countryCode} ',
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(PhoneNumber.nationalLength),
            ],
            onSubmitted: (_) => _add(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextAction(
                label: l10n.actionCancel,
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _adding = false;
                        _error = null;
                      }),
              ),
              const Gap.sm(),
              Flexible(
                child: SecondaryButton(
                  label: l10n.attendantsAdd,
                  isLoading: _busy,
                  onPressed: _add,
                ),
              ),
            ],
          ),
          const Gap.md(),
        ],
        if (error != null) ...[
          AppBanner(tone: StatusTone.danger, message: error),
          const Gap.md(),
        ],
        switch (attendants) {
          AsyncData(:final value) when value.isEmpty => Text(
            l10n.attendantsEmpty,
            style: text.body.copyWith(color: colors.textSecondary),
          ),
          AsyncData(:final value) => AppListGroup(
            children: [
              for (final attendant in value)
                AppListRow(
                  icon: Icons.badge_outlined,
                  title: attendant.name ?? l10n.attendantsNoName,
                  subtitle: attendant.phoneMasked,
                  trailing: TextAction(
                    label: l10n.attendantsRemove,
                    isDestructive: true,
                    onPressed: () => _remove(attendant),
                  ),
                ),
            ],
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
    );
  }
}
