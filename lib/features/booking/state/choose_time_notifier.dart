import 'dart:async';

import 'package:app/core/api/api_exception.dart';
import 'package:app/core/providers.dart';
import 'package:app/core/time/facility_time.dart';
import 'package:app/features/booking/data/booking_repository.dart';
import 'package:app/features/booking/data/models/availability.dart';
import 'package:app/features/booking/data/models/booking_window_request.dart';
import 'package:app/features/booking/data/models/quote.dart';
import 'package:app/features/parking_lot/data/models/parking_lot.dart';
import 'package:app/features/parking_lot/state/parking_lot_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final chooseTimeProvider = AsyncNotifierProvider.autoDispose
    .family<ChooseTimeNotifier, ChooseTimeState, String>(
      ChooseTimeNotifier.new,
    );

/// What the API said about the chosen window.
sealed class Pricing {
  const Pricing();
}

class PricingLoading extends Pricing {
  const PricingLoading();
}

class Priced extends Pricing {
  const Priced({required this.quote, required this.availability});

  final Quote quote;
  final Availability availability;
}

/// The window cannot be priced or booked; the code says why.
class PricingFailed extends Pricing {
  const PricingFailed(this.failure);

  final ApiException failure;
}

class ChooseTimeState {
  const ChooseTimeState({
    required this.lot,
    required this.vehicleType,
    required this.startAt,
    required this.endAt,
    required this.pricing,
  });

  final ParkingLot lot;

  /// A vehicle-type code the facility has spaces for.
  final String vehicleType;

  /// UTC instants.
  final DateTime startAt;
  final DateTime endAt;
  final Pricing pricing;

  ChooseTimeState _with({
    String? vehicleType,
    DateTime? startAt,
    DateTime? endAt,
    Pricing? pricing,
  }) => ChooseTimeState(
    lot: lot,
    vehicleType: vehicleType ?? this.vehicleType,
    startAt: startAt ?? this.startAt,
    endAt: endAt ?? this.endAt,
    pricing: pricing ?? this.pricing,
  );
}

/// The customer's choice of vehicle type and window for one facility,
/// with the API's price and availability for it. The app calculates
/// neither; it asks again whenever the choice changes.
class ChooseTimeNotifier
    extends AutoDisposeFamilyAsyncNotifier<ChooseTimeState, String> {
  static const Duration defaultStay = Duration(hours: 2);
  static const Duration minimumStay = Duration(hours: 1);

  // Answers to an older choice are dropped.
  int _generation = 0;

  @override
  Future<ChooseTimeState> build(String arg) async {
    final lot = await ref.watch(parkingLotProvider(arg).future);
    final start = _nextHalfHour(ref.read(clockProvider)(), lot.timezone);

    final initial = ChooseTimeState(
      lot: lot,
      vehicleType: lot.pools.isEmpty ? '' : lot.pools.first.vehicleType.code,
      startAt: start,
      endAt: start.add(defaultStay),
      pricing: const PricingLoading(),
    );
    unawaited(Future.microtask(_price));
    return initial;
  }

  void setVehicleType(String code) =>
      _change((s) => s._with(vehicleType: code));

  /// Moves the arrival and keeps the length of the stay.
  void setStart(DateTime startAt) => _change((s) {
    final stay = s.endAt.difference(s.startAt);
    return s._with(startAt: startAt, endAt: startAt.add(stay));
  });

  /// Moves the departure. A departure at or before the arrival becomes the
  /// shortest stay, so the screen never shows an impossible window.
  void setEnd(DateTime endAt) => _change(
    (s) => s._with(
      endAt: endAt.isAfter(s.startAt) ? endAt : s.startAt.add(minimumStay),
    ),
  );

  /// Asks again for the same choice.
  void retry() => _change((s) => s);

  void _change(ChooseTimeState Function(ChooseTimeState) update) {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncData(update(current)._with(pricing: const PricingLoading()));
    _price();
  }

  Future<void> _price() async {
    final current = state.valueOrNull;
    if (current == null || current.vehicleType.isEmpty) return;

    final generation = ++_generation;
    final request = BookingWindowRequest(
      parkingLotId: current.lot.id,
      vehicleType: current.vehicleType,
      startAt: current.startAt,
      endAt: current.endAt,
    );
    final repository = ref.read(bookingRepositoryProvider);

    Pricing result;
    try {
      // The quote is asked first: it refuses an invalid window with the
      // reason, and then there is nothing to check availability for.
      final quote = await repository.quote(request);
      final availability = await repository.availability(request);
      result = Priced(quote: quote, availability: availability);
    } on ApiException catch (failure) {
      result = PricingFailed(failure);
    }

    final latest = state.valueOrNull;
    if (generation != _generation || latest == null) return;
    state = AsyncData(latest._with(pricing: result));
  }

  /// The next half hour on the facility's clock, at least a few minutes
  /// away so the default is still in the future when the user confirms.
  static DateTime _nextHalfHour(DateTime now, String zone) {
    final wall = FacilityTime.toWall(
      now.add(const Duration(minutes: 10)),
      zone,
    );
    final minutes = wall.minute <= 30 ? 30 : 60;
    final rounded = DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
    ).add(Duration(minutes: minutes));
    return FacilityTime.fromWall(rounded, zone);
  }
}
