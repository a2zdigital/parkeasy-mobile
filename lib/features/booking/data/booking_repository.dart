import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/json_converters.dart';
import 'package:app/core/api/pagination.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/booking/data/models/availability.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/booking/data/models/booking_window_request.dart';
import 'package:app/features/booking/data/models/create_booking_request.dart';
import 'package:app/features/booking/data/models/quote.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(ref.watch(apiClientProvider)),
);

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

  /// The signed-in customer's bookings, newest first.
  Future<CursorPage<Booking>> mine({String? cursor}) async =>
      CursorPage.fromJson(
        await _api.get('/bookings', query: {'cursor': cursor}),
        Booking.fromJson,
      );

  Future<Booking> find(String id) async =>
      Booking.fromJson(ApiClient.object(await _api.get('/bookings/$id')));

  /// Cancels a booking. The returned booking says whether a refund is due.
  Future<Booking> cancel(String id) async => Booking.fromJson(
    ApiClient.object(await _api.post('/bookings/$id/cancel', body: const {})),
  );
}
