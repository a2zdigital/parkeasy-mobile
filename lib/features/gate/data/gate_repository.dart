import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:app/features/auth/state/session_state.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A signed QR pass from a customer's app (`PE1.…`). It is sent to the API
/// exactly as scanned: never upper-cased, trimmed of dashes or shown.
bool isGatePass(String scanned) => scanned.trim().startsWith('PE1.');

/// A facility where the signed-in person works the gate.
class GateFacility {
  const GateFacility({required this.id, required this.name});

  final String id;
  final String name;
}

final gateRepositoryProvider = Provider<GateRepository>(
  (ref) => GateRepository(ref.watch(apiClientProvider)),
);

/// The facilities where the signed-in person is a gate attendant. Empty for
/// most people, and for guests (nothing is asked).
final gateFacilitiesProvider = FutureProvider.autoDispose<List<GateFacility>>((
  ref,
) async {
  final signedIn = ref.watch(
    sessionControllerProvider.select((session) => session is SignedIn),
  );
  if (!signedIn) return const [];
  try {
    return await ref.watch(gateRepositoryProvider).facilities();
  } on ApiException {
    return const [];
  }
});

/// The gate for attendants: check vehicles in and out by the customer's code
/// or QR pass, at the facilities an owner gave them.
class GateRepository {
  const GateRepository(this._api);

  final ApiClient _api;

  Future<List<GateFacility>> facilities() async {
    final data = (await _api.get('/gate/facilities'))['data'];
    if (data is! List) throw const ApiException(code: ApiErrorCode.unknown);
    return [
      for (final item in data)
        if (item case {'id': final String id, 'name': final String name})
          GateFacility(id: id, name: name),
    ];
  }

  Future<Booking> checkIn(String code) async => Booking.fromJson(
    ApiClient.object(await _api.post('/gate/check-in', body: {'code': code})),
  );

  Future<Booking> checkOut(String code) async => Booking.fromJson(
    ApiClient.object(await _api.post('/gate/check-out', body: {'code': code})),
  );
}
