// Live contract check: the app's own data models parse what a real, running
// backend returns. Skipped unless LIVE_API_BASE_URL is set, so the normal
// test run never touches a network. Tokens are read from files named by
// LIVE_CUSTOMER_TOKEN_FILE and LIVE_OWNER_TOKEN_FILE and never printed.
@Tags(['live'])
library;

import 'dart:io';

import 'package:app/features/auth/data/models/user.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/booking/data/models/quote.dart';
import 'package:app/features/owner/data/models/owner_document.dart';
import 'package:app/features/owner/data/models/owner_earnings.dart';
import 'package:app/features/owner/data/models/owner_parking_lot.dart';
import 'package:app/features/parking_lot/data/models/facility_review.dart';
import 'package:app/features/parking_lot/data/models/parking_lot.dart';
import 'package:app/features/parking_lot/data/models/parking_lot_summary.dart';
import 'package:app/features/payment/data/models/booking_payment.dart';
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = Platform.environment['LIVE_API_BASE_URL'];
  final skip = base == null || base.isEmpty
      ? 'Set LIVE_API_BASE_URL to run against a live backend'
      : null;

  Dio client([String? tokenFile]) {
    final headers = <String, String>{'Accept': 'application/json'};
    final path = tokenFile == null ? null : Platform.environment[tokenFile];
    if (path != null) {
      headers['Authorization'] =
          'Bearer ${File(path).readAsStringSync().trim()}';
    }
    return Dio(
      BaseOptions(
        baseUrl: base ?? '',
        headers: headers,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );
  }

  Map<String, dynamic> data(Response<dynamic> r) =>
      (r.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  List<Map<String, dynamic>> list(Response<dynamic> r) =>
      ((r.data as Map<String, dynamic>)['data'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

  final lotId = Platform.environment['LIVE_LOT_ID'] ?? '';

  test(
    'search results parse as ParkingLotSummary, with free spaces for a window',
    () async {
      final start = DateTime.now().toUtc().add(const Duration(days: 4));
      final r = await client().get<dynamic>(
        '/parking-lots',
        queryParameters: {
          'lat': 12.97,
          'lng': 77.60,
          'radius_km': 5,
          'start_at': start.toIso8601String(),
          'end_at': start.add(const Duration(hours: 2)).toIso8601String(),
        },
      );
      final lots = list(r).map(ParkingLotSummary.fromJson).toList();
      expect(lots, isNotEmpty);
      expect(lots.any((l) => l.id == lotId), isTrue);
    },
    skip: skip,
  );

  test('facility detail and its reviews parse', () async {
    final lot = ParkingLot.fromJson(
      data(await client().get<dynamic>('/parking-lots/$lotId')),
    );
    expect(lot.id, lotId);
    final reviews = list(
      await client().get<dynamic>('/parking-lots/$lotId/ratings'),
    ).map(FacilityReview.fromJson).toList();
    expect(reviews, isNotEmpty);
  }, skip: skip);

  test('a quote parses with exact decimal amounts', () async {
    final start = DateTime.now().toUtc().add(const Duration(days: 5));
    final quote = Quote.fromJson(
      data(
        await client('LIVE_CUSTOMER_TOKEN_FILE').post<dynamic>(
          '/bookings/quote',
          data: {
            'parking_lot_id': lotId,
            'vehicle_type': 'car',
            'start_at': '${start.toIso8601String().split('.').first}Z',
            'end_at':
                '${start.add(const Duration(hours: 2)).toIso8601String().split('.').first}Z',
          },
        ),
      ),
    );
    expect(quote.totalAmount, Decimal.parse('80.00'));
    expect(quote.baseAmount, quote.totalAmount);
  }, skip: skip);

  test('the customer profile, bookings and a payment parse', () async {
    final c = client('LIVE_CUSTOMER_TOKEN_FILE');
    final me = User.fromJson(data(await c.get<dynamic>('/me')));
    expect(me.name, 'E2E Customer');
    final bookings = list(
      await c.get<dynamic>('/bookings'),
    ).map(Booking.fromJson).toList();
    expect(bookings, isNotEmpty);
    for (final b in bookings) {
      expect(b.totalAmount, b.baseAmount);
    }
    final online = bookings
        .where((b) => b.paymentMode.name == 'online')
        .toList();
    expect(online, isNotEmpty);
    final payment = BookingPayment.fromJson(
      data(await c.get<dynamic>('/bookings/${online.first.id}/payment')),
    );
    expect(payment, isNotNull);
  }, skip: skip);

  test(
    "the owner's facilities, documents, bookings and earnings parse",
    () async {
      final o = client('LIVE_OWNER_TOKEN_FILE');
      final lots = list(
        await o.get<dynamic>('/owner/parking-lots'),
      ).map(OwnerParkingLot.fromJson).toList();
      expect(lots.any((l) => l.lot.id == lotId), isTrue);
      final docs = list(
        await o.get<dynamic>('/owner/application/documents'),
      ).map(OwnerDocument.fromJson).toList();
      expect(
        docs.every(
          (d) => d.scanStatus == DocumentScanStatus.clean && d.url != null,
        ),
        isTrue,
      );
      final bookings = list(
        await o.get<dynamic>('/owner/bookings'),
      ).map(Booking.fromJson).toList();
      expect(bookings, isNotEmpty);
      final earnings = OwnerEarnings.fromJson(
        data(await o.get<dynamic>('/owner/earnings')),
      );
      expect(earnings, isNotNull);
    },
    skip: skip,
  );
}
