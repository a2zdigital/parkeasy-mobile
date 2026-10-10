import 'package:app/features/booking/data/models/booking_status.dart';
import 'package:app/features/booking/data/models/payment_mode.dart';
import 'package:app/features/payment/data/models/booking_payment.dart';
import 'package:app/features/payment/data/models/payment_order_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> paymentJson() => {
    'payment_mode': 'online',
    'booking_status': 'awaiting_payment',
    'payment_required': true,
    'order': {
      'id': '01M4JQSZSNAVTVCMS8A7AJ0ORD',
      'booking_id': '01M4JQYWW2WEFYAASEC49S6PW3',
      'status': 'created',
      'amount': '80.00',
      'currency': 'INR',
      'provider': 'razorpay',
      'checkout': {
        'provider': 'razorpay',
        'key_id': 'rzp_test_public',
        'order_id': 'order_abc',
        'amount': 8000,
      },
      'expires_at': '2026-11-02T04:10:10Z',
      'paid_at': null,
    },
  };

  test('BookingPayment parses an open order with its checkout details', () {
    final payment = BookingPayment.fromJson(paymentJson());

    expect(payment.paymentMode, PaymentMode.online);
    expect(payment.bookingStatus, BookingStatus.awaitingPayment);
    expect(payment.paymentRequired, isTrue);
    expect(payment.order?.status, PaymentOrderStatus.created);
    expect(payment.order?.total.toWire(), '80.00');
    expect(payment.order?.checkout?['order_id'], 'order_abc');
    expect(payment.order?.paidAt, isNull);
  });

  test('BookingPayment parses a booking with no order', () {
    final payment = BookingPayment.fromJson({
      'payment_mode': 'on_site',
      'booking_status': 'confirmed',
      'payment_required': false,
      'order': null,
    });

    expect(payment.order, isNull);
  });

  test('an order status added later does not look like success', () {
    final json = paymentJson();
    (json['order'] as Map<String, dynamic>)['status'] = 'authorised';

    final order = BookingPayment.fromJson(json).order!;

    expect(order.status, PaymentOrderStatus.unknown);
    expect(order.status, isNot(PaymentOrderStatus.succeeded));
  });
}
