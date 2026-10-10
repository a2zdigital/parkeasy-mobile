import 'package:app/app/routes.dart';
import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_filter_chip.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/app_text_field.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/features/owner/data/models/owner_parking_lot.dart';
import 'package:app/features/owner/data/models/parking_lot_input.dart';
import 'package:app/features/owner/data/models/parking_lot_options.dart';
import 'package:app/features/owner/data/owner_repository.dart';
import 'package:app/features/owner/state/owner_facility_notifier.dart';
import 'package:app/features/owner/state/owner_lists.dart';
import 'package:app/features/owner/ui/owner_common.dart';
import 'package:app/features/parking_lot/data/models/booking_mode.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Creates a facility, or edits the details of one. With [facilityId]
/// null it creates a draft and moves on to setting it up.
class FacilityFormScreen extends ConsumerWidget {
  const FacilityFormScreen({this.facilityId, super.key});

  final String? facilityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final id = facilityId;
    final title = id == null ? l10n.facilityNewTitle : l10n.facilityEditTitle;
    final options = ref.watch(facilityOptionsProvider);
    final existing = id == null ? null : ref.watch(ownerFacilityProvider(id));

    Widget failed(Object error, VoidCallback retry) {
      final failure = error is ApiException
          ? error
          : const ApiException(code: ApiErrorCode.unknown);
      return AppScaffold(
        title: title,
        body: Center(
          child: ErrorState(
            failure: failure,
            message: ownerAccessText(l10n, failure),
            onRetry: retry,
          ),
        ),
      );
    }

    final loading = AppScaffold(
      title: title,
      body: const Column(children: [Gap.lg(), SkeletonCard()]),
    );

    if (options.hasError) {
      return failed(
        options.error!,
        () => ref.invalidate(facilityOptionsProvider),
      );
    }
    if (existing != null && existing.hasError) {
      return failed(
        existing.error!,
        () => ref.invalidate(ownerFacilityProvider(id!)),
      );
    }
    final loadedOptions = options.valueOrNull;
    final facility = existing?.valueOrNull?.facility;
    if (loadedOptions == null || (id != null && facility == null)) {
      return loading;
    }

    return _Form(title: title, options: loadedOptions, facility: facility);
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.title, required this.options, this.facility});

  final String title;
  final ParkingLotOptions options;
  final OwnerParkingLot? facility;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  // Field keys are the API's field names, so its validation errors land
  // on the right field without a translation table.
  static const _required = [
    'name',
    'address_line',
    'city',
    'state',
    'postal_code',
    'latitude',
    'longitude',
  ];

  late final Map<String, TextEditingController> _text;
  late BookingMode _mode;
  late bool _online;
  late bool _onsite;
  late Set<String> _amenities;

  Map<String, String> _errors = const {};
  ApiException? _failure;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final lot = widget.facility?.lot;
    _text = {
      'name': TextEditingController(text: lot?.name),
      'description': TextEditingController(text: lot?.description),
      'address_line': TextEditingController(text: lot?.addressLine),
      'city': TextEditingController(text: lot?.city),
      'state': TextEditingController(text: lot?.state),
      'postal_code': TextEditingController(text: lot?.postalCode),
      'latitude': TextEditingController(text: lot?.latitude.toString()),
      'longitude': TextEditingController(text: lot?.longitude.toString()),
    };
    _mode = lot?.bookingMode ?? widget.options.defaultBookingMode;
    _online = lot?.acceptsOnlinePayment ?? true;
    _onsite = lot?.acceptsOnsitePayment ?? true;
    _amenities = {...?lot?.amenities.map((amenity) => amenity.code)};
  }

  @override
  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _value(String key) => _text[key]!.text.trim();

  Future<void> _save() async {
    if (_saving) return;
    final l10n = context.l10n;

    final errors = <String, String>{
      for (final key in _required)
        if (_value(key).isEmpty) key: l10n.facilityRequired,
    };
    final latitude = double.tryParse(_value('latitude'));
    final longitude = double.tryParse(_value('longitude'));
    if (_value('latitude').isNotEmpty &&
        (latitude == null || latitude.abs() > 90)) {
      errors['latitude'] = l10n.facilityNumberInvalid;
    }
    if (_value('longitude').isNotEmpty &&
        (longitude == null || longitude.abs() > 180)) {
      errors['longitude'] = l10n.facilityNumberInvalid;
    }
    if (!_online && !_onsite) {
      errors['payments'] = l10n.facilityPaymentRequired;
    }
    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
        _failure = null;
      });
      return;
    }

    final input = ParkingLotInput(
      name: _value('name'),
      description: _value('description').isEmpty ? null : _value('description'),
      addressLine: _value('address_line'),
      city: _value('city'),
      state: _value('state'),
      postalCode: _value('postal_code'),
      latitude: latitude,
      longitude: longitude,
      bookingMode: _mode,
      acceptsOnlinePayment: _online,
      acceptsOnsitePayment: _onsite,
      amenities: _amenities.toList(),
    );

    setState(() {
      _saving = true;
      _errors = const {};
      _failure = null;
    });
    try {
      final existing = widget.facility;
      if (existing == null) {
        final created = await ref
            .read(ownerRepositoryProvider)
            .createFacility(input);
        ref.invalidate(ownerFacilitiesProvider);
        if (mounted) {
          // Replace the form with the new facility's set-up screen.
          context.pushReplacement(Routes.ownerFacility(created.lot.id));
        }
      } else {
        await ref
            .read(ownerFacilityProvider(existing.lot.id).notifier)
            .saveDetails(input);
        if (mounted) context.pop();
      }
    } on ApiException catch (failure) {
      if (!mounted) return;
      final fields = failure.code == ApiErrorCode.validationFailed
          ? failure.fieldErrors
          : const <String, List<String>>{};
      setState(() {
        _saving = false;
        // The API's own messages name the problem precisely; they are
        // shown as given because the app cannot know every rule.
        _errors = {
          for (final entry in fields.entries)
            if (entry.value.isNotEmpty) entry.key: entry.value.first,
        };
        _failure = fields.isEmpty ? failure : null;
      });
    }
  }

  Widget _field(
    String key,
    String label, {
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.none,
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.sm),
    child: AppTextField(
      label: label,
      controller: _text[key],
      enabled: !_saving,
      errorText: _errors[key],
      helperText: helper,
      keyboardType: keyboard,
      textCapitalization: capitalization,
      textInputAction: TextInputAction.next,
      onChanged: (_) {
        if (_errors.containsKey(key)) {
          setState(() => _errors = {..._errors}..remove(key));
        }
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final failure = _failure;
    final paymentError = _errors['payments'];
    const decimal = TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    );

    String modeLabel(BookingMode mode) => switch (mode) {
      BookingMode.instant => l10n.modeInstant,
      BookingMode.ownerApproval => l10n.modeOwnerApproval,
      BookingMode.unknown => mode.wire,
    };

    return AppScaffold(
      title: widget.title,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap.md(),
          _field(
            'name',
            l10n.facilityName,
            capitalization: TextCapitalization.words,
          ),
          _field(
            'description',
            l10n.facilityDescription,
            capitalization: TextCapitalization.sentences,
          ),
          _field(
            'address_line',
            l10n.facilityAddress,
            capitalization: TextCapitalization.words,
          ),
          _field(
            'city',
            l10n.facilityCity,
            capitalization: TextCapitalization.words,
          ),
          _field(
            'state',
            l10n.facilityState,
            capitalization: TextCapitalization.words,
          ),
          _field(
            'postal_code',
            l10n.facilityPostalCode,
            keyboard: TextInputType.number,
          ),
          _field('latitude', l10n.facilityLatitude, keyboard: decimal),
          _field(
            'longitude',
            l10n.facilityLongitude,
            keyboard: decimal,
            helper: l10n.facilityLocationHelp,
          ),
          SectionHeader(l10n.facilityBookingMode),
          Wrap(
            spacing: AppSpace.sm,
            children: [
              for (final mode in widget.options.selectableBookingModes)
                if (mode != BookingMode.unknown)
                  AppFilterChip(
                    label: modeLabel(mode),
                    isSelected: _mode == mode,
                    onPressed: _saving
                        ? null
                        : () => setState(() => _mode = mode),
                  ),
            ],
          ),
          SectionHeader(l10n.facilityPayments),
          Wrap(
            spacing: AppSpace.sm,
            children: [
              AppFilterChip(
                label: l10n.facilityPayOnline,
                isSelected: _online,
                onPressed: _saving
                    ? null
                    : () => setState(() => _online = !_online),
              ),
              AppFilterChip(
                label: l10n.facilityPayOnsite,
                isSelected: _onsite,
                onPressed: _saving
                    ? null
                    : () => setState(() => _onsite = !_onsite),
              ),
            ],
          ),
          if (paymentError != null)
            Text(
              paymentError,
              style: text.bodySmall.copyWith(color: colors.danger.solid),
            ),
          if (widget.options.amenities.isNotEmpty) ...[
            SectionHeader(l10n.lotAmenities),
            Wrap(
              spacing: AppSpace.sm,
              children: [
                for (final amenity in widget.options.amenities)
                  AppFilterChip(
                    label: amenity.name,
                    isSelected: _amenities.contains(amenity.code),
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            if (!_amenities.remove(amenity.code)) {
                              _amenities.add(amenity.code);
                            }
                          }),
                  ),
              ],
            ),
          ],
          if (failure != null) ...[
            const Gap.md(),
            AppBanner(
              tone: StatusTone.danger,
              message: facilityFailureText(l10n, failure),
            ),
          ],
          const Gap.xl(),
        ],
      ),
      bottom: PrimaryButton(
        label: widget.facility == null
            ? l10n.facilityCreate
            : l10n.facilitySave,
        isLoading: _saving,
        onPressed: _save,
      ),
    );
  }
}

/// The words for a refused change to a facility.
String facilityFailureText(AppLocalizations l10n, ApiException failure) =>
    switch (failure.code) {
      ApiErrorCode.parkingLotIncomplete => l10n.errFacilityIncomplete,
      ApiErrorCode.parkingLotUnderReview ||
      ApiErrorCode.invalidReviewState => l10n.errFacilityUnderReview,
      ApiErrorCode.parkingLotLocationLocked => l10n.errLocationLocked,
      ApiErrorCode.inventoryPoolExists => l10n.errPoolExists,
      _ => ownerAccessText(l10n, failure) ?? l10n.describe(failure),
    };
