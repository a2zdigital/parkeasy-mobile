import 'dart:async';

import 'package:app/app/routes.dart';
import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/location/location_service.dart';
import 'package:app/core/maps/location_picker.dart';
import 'package:app/core/motion/motion.dart';
import 'package:app/core/providers.dart';
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
import 'package:app/features/search/data/models/location_suggestion.dart';
import 'package:app/features/search/data/search_repository.dart';
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

/// Where the facility's coordinates came from, to say so to the owner.
enum _LocationSource { saved, place, address, phone, typed, map }

/// Which search the suggestions on screen answer.
enum _SuggestionsFor { name, address }

/// A Google Maps formatted address split into the form's fields. Indian
/// addresses read "…, City, State 560001, India"; anything that does not
/// follow that shape goes whole into the street address.
@visibleForTesting
({String street, String? city, String? state, String? postalCode})
splitPlaceAddress(String address) {
  final parts = address
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isNotEmpty && parts.last.toLowerCase() == 'india') {
    parts.removeLast();
  }

  final pin = RegExp(r'\b(\d{6})\b');
  final stateIndex = parts.lastIndexWhere(pin.hasMatch);
  if (stateIndex < 1) {
    return (
      street: parts.join(', '),
      city: null,
      state: null,
      postalCode: null,
    );
  }

  final postalCode = pin.firstMatch(parts[stateIndex])!.group(1);
  final state = parts[stateIndex].replaceFirst(pin, '').trim();
  final city = parts[stateIndex - 1];
  final street = parts.sublist(0, stateIndex - 1).join(', ');
  return (
    street: street.isEmpty ? city : street,
    city: city,
    state: state.isEmpty ? null : state,
    postalCode: postalCode,
  );
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
  ];

  late final Map<String, TextEditingController> _text;
  late BookingMode _mode;
  late bool _online;
  late bool _onsite;
  late Set<String> _amenities;

  /// The coordinate fields, for fine adjustment, are folded away until
  /// asked for.
  bool _showCoordinates = false;
  bool _locating = false;
  _LocationSource? _source;

  /// The address the coordinates belong to. If it changes after a lookup,
  /// the owner must confirm the location again before saving.
  String? _locatedFor;
  LocationSuggestion? _place;
  String? _locationError;

  /// Matches waiting for the owner to choose one; never chosen for them.
  List<LocationSuggestion> _suggestions = const [];
  _SuggestionsFor? _suggestionsFor;

  /// The name was searched on Google Maps and nothing matched.
  bool _nameNotFound = false;

  /// The search could not reach the server; it can be tried again.
  bool _nameSearchFailed = false;

  /// The last query sent, so the same text is not searched twice.
  String? _nameSearchedFor;
  final _nameFocus = FocusNode();

  /// Typing waits for a pause before searching (see [_searchDelay]).
  Timer? _debounce;

  /// Each search's number: an older answer arriving late is ignored.
  int _searchGeneration = 0;

  /// The manual location options are shown only when the place search did
  /// not settle the location, or when the owner asks to change it.
  bool _showManual = false;

  /// Why the phone's location could not be used, when it could not.
  LocationFailure? _phoneFailure;

  static const _searchDelay = Duration(milliseconds: 700);

  Map<String, String> _errors = const {};
  ApiException? _failure;
  bool _saving = false;

  bool get _isNew => widget.facility == null;

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
    _source = lot == null ? null : _LocationSource.saved;
    if (lot != null) {
      _locatedFor = _addressQuery;
      _nameSearchedFor = _placeQuery;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameFocus.dispose();
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _value(String key) => _text[key]!.text.trim();

  /// The address as one line, for the place search.
  String get _addressQuery => [
    _value('address_line'),
    _value('city'),
    '${_value('state')} ${_value('postal_code')}'.trim(),
  ].where((part) => part.isNotEmpty).join(', ');

  bool get _hasCoordinates =>
      double.tryParse(_value('latitude')) != null &&
      double.tryParse(_value('longitude')) != null;

  void _setCoordinates(double latitude, double longitude) {
    _text['latitude']!.text = latitude.toStringAsFixed(6);
    _text['longitude']!.text = longitude.toStringAsFixed(6);
  }

  void _clearLocationErrors() {
    _locationError = null;
    _errors = {..._errors}
      ..remove('location')
      ..remove('latitude')
      ..remove('longitude');
  }

  /// The name with whatever address details are entered, for the place
  /// search.
  String get _placeQuery => [
    _value('name'),
    _value('address_line'),
    _value('city'),
    _value('postal_code'),
  ].where((part) => part.isNotEmpty).join(', ');

  /// While the owner types the name or address, search once they pause.
  /// Only while no location is set: a chosen location is never replaced by
  /// typing.
  void _scheduleSearch() {
    _debounce?.cancel();
    if (_source != null || _value('name').length < 3) return;
    _debounce = Timer(_searchDelay, () => _searchByName(automatic: true));
  }

  /// Whether a place's name is the facility's name, ignoring case, spaces
  /// and punctuation, or one contains the other.
  static bool _sameName(String place, String facility) {
    String plain(String text) =>
        text.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    final a = plain(place);
    final b = plain(facility);
    return a.isNotEmpty &&
        b.isNotEmpty &&
        (a == b || a.contains(b) || b.contains(a));
  }

  /// Searches Google Maps (through the API's place search) for the
  /// facility. One result with the facility's own name is taken and shown
  /// for the owner to confirm; anything else is listed for them to choose
  /// from, and no result opens the manual options.
  Future<void> _searchByName({bool automatic = false}) async {
    _debounce?.cancel();
    final name = _value('name');
    if (name.length < 3 || _saving) return;
    final query = _placeQuery;
    if (automatic && (_source != null || query == _nameSearchedFor)) return;
    final l10n = context.l10n;
    final generation = ++_searchGeneration;

    setState(() {
      _locating = true;
      _nameSearchedFor = query;
      _nameNotFound = false;
      _nameSearchFailed = false;
      _locationError = null;
      _suggestions = const [];
      _suggestionsFor = null;
    });
    try {
      final matches = await ref
          .read(searchRepositoryProvider)
          .searchLocations(query);
      if (!mounted || generation != _searchGeneration) return;
      final reliable =
          matches.length == 1 && _sameName(matches.single.name, name);
      setState(() {
        _locating = false;
        if (matches.isEmpty) {
          _nameNotFound = true;
          _showManual = true;
        } else if (reliable) {
          _applyPlace(matches.single);
        } else {
          _suggestions = matches;
          _suggestionsFor = _SuggestionsFor.name;
        }
      });
    } on ApiException catch (failure) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _locating = false;
        _nameSearchFailed = true;
        _locationError = l10n.describe(failure);
        _showManual = true;
      });
    }
  }

  /// The owner confirmed this Google Maps place as their facility: its
  /// address and coordinates fill the form.
  void _choosePlace(LocationSuggestion place) =>
      setState(() => _applyPlace(place));

  /// Called inside setState.
  void _applyPlace(LocationSuggestion place) {
    // The provider's own address parts win; the formatted address is split
    // only for the parts it did not give.
    final address = splitPlaceAddress(place.address);
    _text['address_line']!.text = place.addressLine ?? address.street;
    if (place.city ?? address.city case final city?) {
      _text['city']!.text = city;
    }
    if (place.state ?? address.state case final state?) {
      _text['state']!.text = state;
    }
    if (place.postalCode ?? address.postalCode case final pin?) {
      _text['postal_code']!.text = pin;
    }
    _setCoordinates(place.latitude, place.longitude);
    _source = _LocationSource.place;
    _place = place;
    _locatedFor = _addressQuery;
    _nameSearchedFor = _placeQuery;
    _suggestions = const [];
    _suggestionsFor = null;
    _nameNotFound = false;
    _showManual = false;
    _phoneFailure = null;
    _clearLocationErrors();
    for (final key in ['address_line', 'city', 'state', 'postal_code']) {
      _errors.remove(key);
    }
  }

  /// None of the suggestions is the facility: the manual options apply.
  void _rejectSuggestions() {
    setState(() {
      _nameNotFound = _suggestionsFor == _SuggestionsFor.name;
      _suggestions = const [];
      _suggestionsFor = null;
      _showManual = true;
    });
  }

  /// Looks the entered address up. One match is used and shown for the
  /// owner to verify; several are listed to choose from.
  Future<void> _findFromAddress() async {
    final l10n = context.l10n;
    final query = _addressQuery;
    if (_value('address_line').isEmpty || _value('city').isEmpty) {
      setState(() => _locationError = l10n.facilityLocationNeedsAddress);
      return;
    }

    setState(() {
      _locating = true;
      _locationError = null;
      _suggestions = const [];
      _suggestionsFor = null;
    });
    try {
      final matches = await ref
          .read(searchRepositoryProvider)
          .searchLocations(query);
      if (!mounted) return;
      setState(() {
        _locating = false;
        if (matches.isEmpty) {
          _locationError = l10n.facilityLocationNotFound;
        } else if (matches.length > 1) {
          _suggestions = matches;
          _suggestionsFor = _SuggestionsFor.address;
        } else {
          _useAddressMatch(matches.single);
        }
      });
    } on ApiException catch (failure) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _locationError = l10n.describe(failure);
      });
    }
  }

  /// Called inside setState: only the coordinates change, not the address
  /// the owner typed.
  void _useAddressMatch(LocationSuggestion match) {
    _setCoordinates(match.latitude, match.longitude);
    _source = _LocationSource.address;
    _locatedFor = _addressQuery;
    _place = match;
    _suggestions = const [];
    _suggestionsFor = null;
    _clearLocationErrors();
  }

  /// Only when the owner chooses it: the phone's own position, for an
  /// owner standing at the facility.
  Future<void> _useCurrentLocation() async {
    final l10n = context.l10n;
    setState(() {
      _locating = true;
      _locationError = null;
      _phoneFailure = null;
    });
    try {
      final position = await ref.read(locationServiceProvider).current();
      if (!mounted) return;
      setState(() {
        _locating = false;
        _setCoordinates(position.latitude, position.longitude);
        _source = _LocationSource.phone;
        _locatedFor = _addressQuery;
        _place = null;
        _clearLocationErrors();
      });
    } on LocationException catch (error) {
      if (mounted) {
        setState(() {
          _locating = false;
          _phoneFailure = error.failure;
          _locationError = switch (error.failure) {
            LocationFailure.denied => l10n.facilityLocationDenied,
            LocationFailure.deniedForever => l10n.facilityLocationDeniedForever,
            LocationFailure.serviceOff => l10n.facilityLocationServiceOff,
            LocationFailure.unavailable => l10n.facilityLocationPhoneFailed,
          };
        });
      }
    }
  }

  /// Opens the map with the pin at the current coordinates, or at the
  /// entered address, so the owner can drag it onto the exact entrance.
  Future<void> _adjustOnMap() async {
    if (!_hasCoordinates &&
        _value('address_line').isNotEmpty &&
        _value('city').isNotEmpty) {
      await _findFromAddress();
      if (!mounted) return;
    }
    final latitude = double.tryParse(_value('latitude'));
    final longitude = double.tryParse(_value('longitude'));
    final origin = ref.read(appConfigProvider).searchOrigin;
    final known = latitude != null && longitude != null;
    final picked = await pickLocationOnMap(
      context,
      start: known
          ? (latitude: latitude, longitude: longitude)
          : (latitude: origin.latitude, longitude: origin.longitude),
      startIsKnown: known,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _setCoordinates(picked.latitude, picked.longitude);
      _source = _LocationSource.map;
      _locatedFor = _addressQuery;
      _place = null;
      _suggestions = const [];
      _suggestionsFor = null;
      _clearLocationErrors();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = context.l10n;

    final errors = <String, String>{
      for (final key in _required)
        if (_value(key).isEmpty) key: l10n.facilityRequired,
    };
    if (!_online && !_onsite) {
      errors['payments'] = l10n.facilityPaymentRequired;
    }

    // The location is never filled in or guessed on save: the owner sets
    // it, and confirms it again if the address changed after a lookup.
    final latitude = double.tryParse(_value('latitude'));
    final longitude = double.tryParse(_value('longitude'));
    if (_value('latitude').isEmpty && _value('longitude').isEmpty) {
      errors['location'] = l10n.facilityLocationRequired;
    } else {
      if (latitude == null || latitude.abs() > 90) {
        errors['latitude'] = l10n.facilityNumberInvalid;
      }
      if (longitude == null || longitude.abs() > 180) {
        errors['longitude'] = l10n.facilityNumberInvalid;
      }
      final lookedUp =
          _source == _LocationSource.address ||
          _source == _LocationSource.saved;
      if (lookedUp && _locatedFor != _addressQuery) {
        errors['location'] = l10n.facilityLocationStale;
      }
    }
    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
        _failure = null;
        if (errors.containsKey('latitude') || errors.containsKey('longitude')) {
          _showCoordinates = true;
        }
        if (errors.containsKey('location') ||
            errors.containsKey('latitude') ||
            errors.containsKey('longitude')) {
          _showManual = true;
        }
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
        if (_errors.containsKey('latitude') ||
            _errors.containsKey('longitude')) {
          _showCoordinates = true;
        }
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
    FocusNode? focusNode,
    TextInputAction action = TextInputAction.next,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    Widget? suffix,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.md),
    child: AppTextField(
      label: label,
      controller: _text[key],
      focusNode: focusNode,
      enabled: !_saving,
      errorText: _errors[key],
      helperText: helper,
      keyboardType: keyboard,
      textCapitalization: capitalization,
      textInputAction: action,
      onSubmitted: onSubmitted,
      suffixIcon: suffix,
      onChanged: (value) {
        if (_errors.containsKey(key)) {
          setState(() => _errors = {..._errors}..remove(key));
        }
        onChanged?.call(value);
      },
    ),
  );

  /// Matches for the owner to choose from, with a way out when none fits.
  Widget _suggestionList(AppLocalizations l10n) {
    final text = context.text;
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _suggestionsFor == _SuggestionsFor.name
                ? l10n.facilityPlaceChoose
                : l10n.facilityAddressChoose,
            style: text.label.copyWith(color: colors.textSecondary),
          ),
          const Gap.xs(),
          for (final place in _suggestions) ...[
            AppCard(
              onTap: _saving
                  ? null
                  : () => _suggestionsFor == _SuggestionsFor.name
                        ? _choosePlace(place)
                        : setState(() => _useAddressMatch(place)),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.place_outlined,
                      color: colors.textSecondary,
                    ),
                  ),
                  const Gap.sm(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(place.name, style: text.body),
                        Text(
                          place.address,
                          style: text.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Gap.xs(),
          ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextAction(
              label: l10n.facilityPlaceNoneMatch,
              onPressed: _saving ? null : _rejectSuggestions,
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationSection(AppLocalizations l10n) {
    final text = context.text;
    final colors = context.colors;
    final latitude = double.tryParse(_value('latitude'));
    final longitude = double.tryParse(_value('longitude'));
    final error = _errors['location'] ?? _locationError;
    final busy = _saving || _locating;
    const decimal = TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    );

    final String status;
    if (latitude == null || longitude == null) {
      status = l10n.facilityLocationNone;
    } else {
      final at =
          '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
      status = switch (_source) {
        _LocationSource.place => l10n.facilityLocationFromPlace(at),
        _LocationSource.address => l10n.facilityLocationFromAddress(at),
        _LocationSource.phone => l10n.facilityLocationFromPhone(at),
        _LocationSource.map => l10n.facilityLocationFromMap(at),
        _ => l10n.facilityLocationAt(at),
      };
    }
    final place = _place;

    // Full-width, one under another, with even spacing.
    Widget option(String label, VoidCallback onPressed) => Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm),
      child: SecondaryButton(label: label, onPressed: busy ? null : onPressed),
    );
    final placeChosen = _source == _LocationSource.place;

    return AppCard(
      child: AnimatedSize(
        duration: reduceMotion(context) ? Duration.zero : AppMotion.base,
        curve: AppMotion.enter,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(status, style: text.body),
            if (place != null &&
                (_source == _LocationSource.place ||
                    _source == _LocationSource.address))
              Text(
                l10n.facilityLocationMatched('${place.name}, ${place.address}'),
                style: text.bodySmall.copyWith(color: colors.textSecondary),
              ),
            if (_nameNotFound) ...[
              const Gap.sm(),
              AppBanner(
                tone: StatusTone.warning,
                message: l10n.facilityPlaceNotFound,
              ),
            ],
            if (error != null) ...[
              const Gap.xs(),
              Text(
                error,
                style: text.bodySmall.copyWith(color: colors.danger.solid),
              ),
            ],
            if (_phoneFailure == LocationFailure.deniedForever)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextAction(
                  label: l10n.locationOpenSettings,
                  onPressed: () =>
                      ref.read(locationServiceProvider).openSettings(),
                ),
              ),
            if (_nameSearchFailed)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextAction(
                  label: l10n.facilityLocationRetry,
                  onPressed: busy ? null : _searchByName,
                ),
              ),
            if (_locating) ...[
              const Gap.sm(),
              Semantics(
                label: l10n.facilityLocationSearching,
                child: const LinearProgressIndicator(),
              ),
            ],
            if (!_showManual) ...[
              const Gap.sm(),
              if (!_hasCoordinates && !_locating)
                Text(
                  l10n.facilityLocationSearchHint,
                  style: text.bodySmall.copyWith(color: colors.textSecondary),
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextAction(
                  label: placeChosen || _hasCoordinates
                      ? l10n.facilityLocationChange
                      : l10n.facilityLocationManual,
                  onPressed: busy
                      ? null
                      : () => setState(() => _showManual = true),
                ),
              ),
            ] else ...[
              // The manual options, one under another, in this order.
              option(l10n.facilityLocationOnMap, _adjustOnMap),
              option(l10n.facilityLocationFind, _findFromAddress),
              option(l10n.facilityLocationUsePhone, _useCurrentLocation),
              option(
                _showCoordinates
                    ? l10n.facilityLocationHideCoordinates
                    : l10n.facilityLocationAdjust,
                () => setState(() => _showCoordinates = !_showCoordinates),
              ),
            ],
            if (_suggestionsFor == _SuggestionsFor.address) ...[
              const Gap.sm(),
              _suggestionList(l10n),
            ],
            if (_showCoordinates && _showManual) ...[
              const Gap.md(),
              _field(
                'latitude',
                l10n.facilityLatitude,
                keyboard: decimal,
                onChanged: (_) => setState(() {
                  _source = _LocationSource.typed;
                  _place = null;
                  _errors = {..._errors}..remove('location');
                }),
              ),
              _field(
                'longitude',
                l10n.facilityLongitude,
                keyboard: decimal,
                helper: l10n.facilityLocationHelp,
                action: TextInputAction.done,
                onChanged: (_) => setState(() {
                  _source = _LocationSource.typed;
                  _place = null;
                  _errors = {..._errors}..remove('location');
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final failure = _failure;
    final paymentError = _errors['payments'];

    return AppScaffold(
      title: widget.title,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap.md(),
          if (_isNew) ...[
            Text(
              l10n.facilityNewIntro,
              style: text.bodySmall.copyWith(color: colors.textSecondary),
            ),
            const Gap.md(),
          ],
          // 1. The facility, looked up on Google Maps as its name is typed.
          SectionHeader(l10n.facilityDetailsSection),
          _field(
            'name',
            l10n.facilityName,
            capitalization: TextCapitalization.words,
            focusNode: _nameFocus,
            action: TextInputAction.search,
            helper: l10n.facilityNameHelp,
            onChanged: (_) => _scheduleSearch(),
            onSubmitted: (_) => _searchByName(),
            suffix: IconButton(
              tooltip: l10n.facilityNameSearch,
              icon: const Icon(Icons.travel_explore),
              onPressed: _saving || _locating ? null : _searchByName,
            ),
          ),
          AnimatedSize(
            duration: reduceMotion(context) ? Duration.zero : AppMotion.base,
            curve: AppMotion.enter,
            alignment: Alignment.topCenter,
            child: _suggestionsFor == _SuggestionsFor.name
                ? _suggestionList(l10n)
                : const SizedBox(width: double.infinity),
          ),
          // 2. Description.
          _field(
            'description',
            l10n.facilityDescription,
            capitalization: TextCapitalization.sentences,
          ),
          // 3. Address, then 4. PIN code. They narrow the place search.
          SectionHeader(l10n.facilityAddressSection),
          _field(
            'address_line',
            l10n.facilityAddress,
            capitalization: TextCapitalization.words,
            onChanged: (_) => _scheduleSearch(),
          ),
          _field(
            'city',
            l10n.facilityCity,
            capitalization: TextCapitalization.words,
            onChanged: (_) => _scheduleSearch(),
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
            action: TextInputAction.done,
          ),
          // 5. Location on the map.
          SectionHeader(l10n.facilityLocation),
          _locationSection(l10n),
          // 6. The remaining details.
          SectionHeader(l10n.facilityBookingMode),
          AppBanner(
            tone: StatusTone.info,
            message: l10n.facilityAutoApprovalNote,
          ),
          SectionHeader(l10n.facilityPayments),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
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
              runSpacing: AppSpace.sm,
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
