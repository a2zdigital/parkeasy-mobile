import 'package:app/features/parking_lot/data/models/allocation_mode.dart';
import 'package:app/features/parking_lot/data/models/booking_mode.dart';
import 'package:app/features/parking_lot/data/models/parking_lot.dart';
import 'package:app/features/parking_lot/data/models/parking_lot_summary.dart';
import 'package:app/features/parking_lot/data/models/rate_type.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> lotJson() => {
  'id': '01M4JQSZSNAVTVCMS8A7AJ0WJ9',
  'name': 'MG Road Metro Parking',
  'description': null,
  'address_line': '12 MG Road',
  'city': 'Bengaluru',
  'state': 'Karnataka',
  'postal_code': '560001',
  'latitude': 12.9756,
  'longitude': 77.605,
  'timezone': 'Asia/Kolkata',
  'booking_mode': 'instant',
  'accepts_online_payment': true,
  'accepts_onsite_payment': true,
  'amenities': [
    {'code': 'covered', 'name': 'Covered'},
    {'code': 'cctv', 'name': 'CCTV'},
  ],
  'operating_hours': [
    {
      'day_of_week': 1,
      'is_closed': false,
      'opens_at': '00:00',
      'closes_at': '24:00',
    },
    {'day_of_week': 7, 'is_closed': true, 'opens_at': null, 'closes_at': null},
  ],
  'pools': [
    {
      'id': '01M4JQSZT0000000000000POOL',
      'vehicle_type': {'code': 'car', 'name': 'Car'},
      'allocation_mode': 'pooled',
      'capacity': 40,
      'is_active': true,
      'rates': [
        {'rate_type': 'hourly', 'amount': '40.00', 'currency': 'INR'},
        {'rate_type': 'daily', 'amount': '250.00', 'currency': 'INR'},
      ],
    },
  ],
};

void main() {
  group('ParkingLot', () {
    test('parses the documented shape', () {
      final lot = ParkingLot.fromJson(lotJson());

      expect(lot.name, 'MG Road Metro Parking');
      expect(lot.description, isNull);
      expect(lot.latitude, 12.9756);
      expect(lot.bookingMode, BookingMode.instant);
      expect(lot.amenities.map((a) => a.code), ['covered', 'cctv']);
      expect(lot.operatingHours.last.isClosed, isTrue);
      expect(lot.operatingHours.last.opensAt, isNull);

      final pool = lot.pools.single;
      expect(pool.vehicleType.code, 'car');
      expect(pool.allocationMode, AllocationMode.pooled);
      expect(pool.rates.first.rateType, RateType.hourly);
      expect(pool.rates.first.price.toWire(), '40.00');
    });

    test('accepts coordinates sent as strings', () {
      final lot = ParkingLot.fromJson({
        ...lotJson(),
        'latitude': '12.9756000',
        'longitude': '77.6050000',
      });

      expect(lot.latitude, 12.9756);
      expect(lot.longitude, 77.605);
    });

    test('survives unknown modes and rate types', () {
      final json = lotJson()..['booking_mode'] = 'auction';
      final pool =
          (json['pools'] as List<Object?>).single! as Map<String, dynamic>;
      pool['allocation_mode'] = 'valet';
      (pool['rates'] as List<Object?>).add({
        'rate_type': 'monthly',
        'amount': '4000.00',
        'currency': 'INR',
      });

      final lot = ParkingLot.fromJson(json);

      expect(lot.bookingMode, BookingMode.unknown);
      expect(lot.pools.single.allocationMode, AllocationMode.unknown);
      expect(lot.pools.single.rates.last.rateType, RateType.unknown);
    });

    test('treats missing lists as empty', () {
      final json = lotJson()
        ..remove('amenities')
        ..remove('operating_hours')
        ..remove('pools');

      final lot = ParkingLot.fromJson(json);

      expect(lot.amenities, isEmpty);
      expect(lot.operatingHours, isEmpty);
      expect(lot.pools, isEmpty);
    });
  });

  group('ParkingLotSummary', () {
    Map<String, dynamic> summaryJson() => {
      'id': '01M4JQSZSNAVTVCMS8A7AJ0WJ9',
      'name': 'MG Road Metro Parking',
      'address_line': '12 MG Road',
      'city': 'Bengaluru',
      'latitude': 12.9756,
      'longitude': 77.605,
      'distance_km': 0.42,
      'booking_mode': 'instant',
      'accepts_online_payment': true,
      'accepts_onsite_payment': true,
      'amenities': ['covered', 'cctv'],
      'pools': [
        {
          'vehicle_type': {'code': 'car', 'name': 'Car'},
          'hourly_rate': '40.00',
          'daily_rate': null,
        },
      ],
      'from_hourly_rate': '40.00',
      'currency': 'INR',
    };

    test('parses a search result', () {
      final summary = ParkingLotSummary.fromJson(summaryJson());

      expect(summary.distanceKm, 0.42);
      expect(summary.amenities, ['covered', 'cctv']);
      expect(summary.pools.single.dailyRate, isNull);
      expect(summary.fromPrice?.toWire(), '40.00');
    });

    test('has no starting price when the facility has no hourly rate', () {
      final summary = ParkingLotSummary.fromJson({
        ...summaryJson(),
        'from_hourly_rate': null,
      });

      expect(summary.fromPrice, isNull);
    });
  });
}
