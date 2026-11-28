import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/api/json_converters.dart';
import 'package:app/core/api/pagination.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/booking/data/models/availability.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/booking/data/models/booking_status.dart';
import 'package:app/features/booking/data/models/booking_window_request.dart';
import 'package:app/features/booking/data/models/create_booking_request.dart';
import 'package:app/features/booking/data/models/quote.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(ref.watch(apiClientProvider)),
);

/// What the customer's QR code holds at the gate.
class CheckInPass {
  const CheckInPass({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;
}

/// The current gate pass for a booking, or null when there is none (the
/// typed code still works, and the QR code then holds the code itself).
final checkInPassProvider = FutureProvider.autoDispose
    .family<CheckInPass?, String>((ref, bookingId) async {
      try {
        return await ref
            .watch(bookingRepositoryProvider)
            .checkInPass(bookingId);
      } on ApiException {
        return null;
      }
    });

/// The current pass for leaving, while the vehicle is parked.
final checkOutPassProvider = FutureProvider.autoDispose
    .family<CheckInPass?, String>((ref, bookingId) async {
      try {
        return await ref
            .watch(bookingRepositoryProvider)
            .checkInPass(bookingId, checkOut: true);
      } on ApiException {
        return null;
      }
    });

class BookingRepository {
  const BookingRepository(this._api);

  static const _time = UtcDateTimeConverter();

  final ApiClient _api;

  /// The price the API calculates for a window. Also refuses windows that
  /// cannot be booked, with the reason as an error code.
  Future<Quote> quote(BookingWindowRequest request) async => Quote.fromJson(
    ApiClient.object(
      await _api.post('/bookings/quote', body: request.toJson()),
    ),
  );

  /// A signed QR pass for the gate. It changes every minute and works for
  /// about two, so the app fetches a new one before [CheckInPass.expiresAt].
  Future<CheckInPass> checkInPass(
    String bookingId, {
    bool checkOut = false,
  }) async {
    final data = ApiClient.object(
      await _api.get(
        '/bookings/$bookingId/${checkOut ? 'check-out-pass' : 'check-in-pass'}',
      ),
    );
    final token = data['token'];
    final expires = data['expires_at'];
    if (token is! String || expires is! String) {
      throw const ApiException(code: ApiErrorCode.unknown);
    }
    return CheckInPass(token: token, expiresAt: _time.fromJson(expires));
  }

  /// Whether a space is free. An estimate: only a booking reserves.
  Future<Availability> availability(BookingWindowRequest request) async =>
      Availability.fromJson(
        ApiClient.object(
          await _api.get(
            '/parking-lots/${request.parkingLotId}/availability',
            query: {
              'vehicle_type': request.vehicleType,
              'start_at': _time.toJson(request.startAt),
              'end_at': _time.toJson(request.endAt),
            },
          ),
        ),
      );

  /// Books a space. [idempotencyKey] must be the same for every retry of
  /// one press of the button, so the API creates one booking however many
  /// times the request arrives.
  Future<Booking> create(
    CreateBookingRequest request, {
    required String idempotencyKey,
  }) async => Booking.fromJson(
    ApiClient.object(
      await _api.post(
        '/bookings',
        body: request.toJson(),
        idempotencyKey: idempotencyKey,
      ),
    ),
  );

  /// The signed-in customer's bookings for one API status, newest first.
  Future<CursorPage<Booking>> mine({
    required BookingStatus status,
    String? cursor,
  }) async => CursorPage.fromJson(
    await _api.get(
      '/bookings',
      query: {'filter[status]': status.wire, 'cursor': cursor},
    ),
    Booking.fromJson,
  );

  Future<Booking> find(String id) async =>
      Booking.fromJson(ApiClient.object(await _api.get('/bookings/$id')));

  /// Rates the facility of a completed booking, once.
  Future<void> rate(String id, int score, String? comment) => _api.post(
    '/bookings/$id/rating',
    body: {'score': score, 'comment': comment},
  );

  /// Cancels a booking. The returned booking says whether a refund is due.
  Future<Booking> cancel(String id) async => Booking.fromJson(
    ApiClient.object(await _api.post('/bookings/$id/cancel', body: const {})),
  );
}
