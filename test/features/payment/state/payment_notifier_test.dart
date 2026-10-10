import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/config/app_config.dart';
import 'package:app/core/payment/checkout_launcher.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:app/features/booking/state/create_booking_notifier.dart';
import 'package:app/features/payment/data/models/checkout_details.dart';
import 'package:app/features/payment/data/models/payment_order.dart';
import 'package:app/features/payment/state/payment_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';
import '../../../support/harness.dart';

void main() {
  const orders = '/bookings/$bookingId/payment-orders';
  const status = '/bookings/$bookingId/payment';

  late Harness harness;
  late ProviderContainer container;
  late FakeCheckoutLauncher checkout;
  var waits = 0;
  var keys = 0;

  PaymentState state() => container.read(paymentProvider(bookingId));
  PaymentNotifier notifier() =>
      container.read(paymentProvider(bookingId).notifier);
  List<RequestOptions> to(String path) =>
      harness.http.requests.where((r) => r.path == path).toList();

  void build({bool simulation = true}) {
    container = ProviderContainer(
      overrides: [
        ...harness.overrides,
        appConfigProvider.overrideWithValue(
          AppConfig.validated(
            apiBaseUrl: 'http://api.test',
            environment: 'local',
            enablePaymentSimulation: simulation,
            searchLatitude: '12.9716',
            searchLongitude: '77.5946',
            searchLabel: 'Bengaluru',
            searchRadiusKm: '25',
          ),
        ),
        checkoutLauncherProvider.overrideWithValue(checkout),
        pollDelayProvider.overrideWithValue((_) async => waits++),
        idempotencyKeyFactoryProvider.overrideWithValue(() => 'key-${++keys}'),
      ],
    );
    addTearDown(container.dispose);
  }

  Future<void> open() async {
    container.listen(paymentProvider(bookingId), (_, _) {});
    await harness.http.idle();
  }

  setUp(() {
    waits = 0;
    keys = 0;
    harness = Harness(token: validToken());
    checkout = FakeCheckoutLauncher();
    build();
  });

  group('with the real provider', () {
    test(
      'opens checkout with what the API sent, never a key of its own',
      () async {
        harness.http
          ..respond(200, {'data': userJson()})
          ..respond(201, {'data': orderJson()})
          ..respond(
            200,
            paymentJson(orderStatus: 'succeeded', bookingStatus: 'confirmed'),
          );
        container.listen(sessionControllerProvider, (_, _) {});
        await container.read(sessionControllerProvider.notifier).restore();
        await open();

        expect(to(orders).single.headers['Idempotency-Key'], 'key-1');
        final request = checkout.opened.single;
        expect(request.keyId, 'rzp_test_public');
        expect(request.orderId, 'order_abc');
        expect(request.amountMinor, 8000);
        expect(request.currency, 'INR');
        expect(request.name, 'Parking Co');
        expect(request.description, 'Booking BK-K2M5XCN4');
        expect(request.contact, '+919000000001');
      },
    );

    test(
      'success in the window is believed only when the API confirms it',
      () async {
        harness.http
          ..respond(201, {'data': orderJson()})
          ..respond(200, paymentJson())
          ..respond(200, paymentJson())
          ..respond(
            200,
            paymentJson(orderStatus: 'succeeded', bookingStatus: 'confirmed'),
          );
        await open();

        expect(state().stage, PaymentStage.succeeded);
        expect(to(status), hasLength(3));
        expect(waits, 2);
      },
    );

    test(
      'if the API never confirms, it is "still confirming", not success and not failure',
      () async {
        harness.http.respond(201, {'data': orderJson()});
        for (var i = 0; i < PaymentNotifier.confirmAttempts; i++) {
          harness.http.respond(200, paymentJson());
        }
        await open();

        expect(state().stage, PaymentStage.stillPending);
        expect(to(status), hasLength(PaymentNotifier.confirmAttempts));
      },
    );

    test(
      'closing the window checks once and reports "not completed"',
      () async {
        checkout.outcome = CheckoutOutcome.dismissed;
        harness.http
          ..respond(201, {'data': orderJson()})
          ..respond(200, paymentJson());
        await open();

        expect(state().stage, PaymentStage.notCompleted);
        expect(to(status), hasLength(1));
        expect(waits, 0);
      },
    );

    test(
      'a payment that landed before the window was closed still counts',
      () async {
        checkout.outcome = CheckoutOutcome.dismissed;
        harness.http
          ..respond(201, {'data': orderJson()})
          ..respond(
            200,
            paymentJson(orderStatus: 'succeeded', bookingStatus: 'confirmed'),
          );
        await open();

        expect(state().stage, PaymentStage.succeeded);
      },
    );

    test(
      'a failed payment is reported and can be tried again with a new order request',
      () async {
        checkout.outcome = CheckoutOutcome.failed;
        harness.http
          ..respond(201, {'data': orderJson()})
          ..respond(200, paymentJson(orderStatus: 'failed'));
        await open();
        expect(state().stage, PaymentStage.failed);

        checkout.outcome = CheckoutOutcome.completed;
        harness.http
          ..respond(201, {'data': orderJson()})
          ..respond(
            200,
            paymentJson(orderStatus: 'succeeded', bookingStatus: 'confirmed'),
          );
        await notifier().start();

        expect(state().stage, PaymentStage.succeeded);
        expect(to(orders).map((r) => r.headers['Idempotency-Key']), [
          'key-1',
          'key-2',
        ]);
      },
    );

    test(
      'a lost connection while confirming is not an answer; it keeps asking',
      () async {
        harness.http
          ..respond(201, {'data': orderJson()})
          ..fail(DioExceptionType.connectionError)
          ..respond(
            200,
            paymentJson(orderStatus: 'succeeded', bookingStatus: 'confirmed'),
          );
        await open();

        expect(state().stage, PaymentStage.succeeded);
      },
    );

    test(
      'an order this build cannot read is "can\'t pay here", and nothing opens',
      () async {
        final order = orderJson()..['checkout'] = {'provider': 'razorpay'};
        harness.http.respond(201, {'data': order});
        await open();

        expect(state().stage, PaymentStage.unavailable);
        expect(checkout.opened, isEmpty);
      },
    );
  });

  group('with the simulated provider', () {
    test('the tester chooses the outcome, and the API still decides', () async {
      harness.http.respond(201, {'data': orderJson(provider: 'fake')});
      await open();
      expect(state().stage, PaymentStage.readyToSimulate);
      expect(checkout.opened, isEmpty);

      harness.http
        ..respond(200, {'data': <String, Object?>{}})
        ..respond(
          200,
          paymentJson(
            orderStatus: 'succeeded',
            bookingStatus: 'confirmed',
            provider: 'fake',
          ),
        );
      await notifier().simulate(succeed: true);

      final simulate = to('/bookings/$bookingId/payment/simulate').single;
      expect(simulate.data, {'outcome': 'success'});
      expect(state().stage, PaymentStage.succeeded);
    });

    test('a simulated failure ends as failed', () async {
      harness.http.respond(201, {'data': orderJson(provider: 'fake')});
      await open();

      harness.http
        ..respond(200, {'data': <String, Object?>{}})
        ..respond(200, paymentJson(orderStatus: 'failed', provider: 'fake'));
      await notifier().simulate(succeed: false);

      expect(to('/bookings/$bookingId/payment/simulate').single.data, {
        'outcome': 'failure',
      });
      expect(state().stage, PaymentStage.failed);
    });

    test('is refused when this build has simulation switched off', () async {
      build(simulation: false);
      harness.http.respond(201, {'data': orderJson(provider: 'fake')});
      await open();

      expect(state().stage, PaymentStage.unavailable);
    });
  });

  group('when the API will not start a payment', () {
    test('already paid counts as success', () async {
      harness.http.respond(409, {
        'error': {'code': 'PAYMENT_ALREADY_COMPLETED', 'message': 'Paid.'},
      });
      await open();

      expect(state().stage, PaymentStage.succeeded);
    });

    test('a refusal is reported with its reason', () async {
      harness.http.respond(409, {
        'error': {'code': 'BOOKING_EXPIRED', 'message': 'Expired.'},
      });
      await open();

      expect(state().stage, PaymentStage.refused);
      expect(state().failure?.code, ApiErrorCode.bookingExpired);
      expect(checkout.opened, isEmpty);
    });

    test(
      'no answer keeps the key, so trying again cannot create two orders',
      () async {
        harness.http.fail(DioExceptionType.receiveTimeout);
        await open();
        expect(state().stage, PaymentStage.refused);
        expect(state().failure?.isTransient, isTrue);

        harness.http
          ..respond(201, {'data': orderJson()})
          ..respond(
            200,
            paymentJson(orderStatus: 'succeeded', bookingStatus: 'confirmed'),
          );
        await notifier().start();

        expect(to(orders).map((r) => r.headers['Idempotency-Key']), [
          'key-1',
          'key-1',
        ]);
      },
    );
  });

  group('CheckoutDetails', () {
    PaymentOrder order(Map<String, dynamic>? checkout) =>
        PaymentOrder.fromJson(orderJson()..['checkout'] = checkout);

    test('reads the provider order', () {
      final details = CheckoutDetails.of(PaymentOrder.fromJson(orderJson()))!;

      expect(details.isSimulated, isFalse);
      expect(details.keyId, 'rzp_test_public');
      expect(details.amountMinor, 8000);
    });

    test('is null for an order that can no longer be paid or is malformed', () {
      expect(CheckoutDetails.of(order(null)), isNull);
      expect(CheckoutDetails.of(order({'provider': 'razorpay'})), isNull);
      expect(
        CheckoutDetails.of(
          order({
            'provider': 'razorpay',
            'order_id': 'o',
            'amount_minor': '8000',
            'currency': 'INR',
          }),
        ),
        isNull,
        reason: 'an amount that is not an integer is not trusted',
      );
      expect(
        CheckoutDetails.of(
          order({
            'provider': 'razorpay',
            'order_id': 'o',
            'amount_minor': 0,
            'currency': 'INR',
          }),
        ),
        isNull,
      );
    });
  });
}
