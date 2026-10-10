import 'package:app/core/api/api_client.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/payment/data/models/booking_payment.dart';
import 'package:app/features/payment/data/models/payment_order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => PaymentRepository(ref.watch(apiClientProvider)),
);

class PaymentRepository {
  const PaymentRepository(this._api);

  final ApiClient _api;

  /// Starts (or returns the open) payment for a booking.
  Future<PaymentOrder> createOrder(
    String bookingId, {
    required String idempotencyKey,
  }) async => PaymentOrder.fromJson(
    ApiClient.object(
      await _api.post(
        '/bookings/$bookingId/payment-orders',
        body: const <String, Object?>{},
        idempotencyKey: idempotencyKey,
      ),
    ),
  );

  /// The payment position of a booking. The only source of truth for
  /// whether a payment succeeded.
  Future<BookingPayment> status(String bookingId) async =>
      BookingPayment.fromJson(
        ApiClient.object(await _api.get('/bookings/$bookingId/payment')),
      );

  /// Finishes or fails a payment on a server that runs the simulated
  /// provider. The endpoint does not exist elsewhere.
  Future<void> simulate(String bookingId, {required bool succeed}) => _api.post(
    '/bookings/$bookingId/payment/simulate',
    body: {'outcome': succeed ? 'success' : 'failure'},
  );
}
