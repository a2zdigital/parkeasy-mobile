import 'package:app/core/api/api_client.dart';
import 'package:app/core/auth/token_store.dart';
import 'package:app/core/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fakes.dart';

/// The app's dependencies with every edge faked: HTTP, token storage and
/// the clock.
class Harness {
  Harness({StoredToken? token, DateTime? now})
    : http = FakeHttpAdapter(),
      tokens = InMemoryTokenStore(token),
      now = now ?? DateTime.utc(2026, 11, 2, 4) {
    // Explore loads as soon as the user is in; by default it finds nothing.
    http.stubs['/parking-lots'] = searchJson(const []);
  }

  final FakeHttpAdapter http;
  final InMemoryTokenStore tokens;
  DateTime now;

  late final List<Override> overrides = [
    appConfigProvider.overrideWithValue(testConfig),
    tokenStoreProvider.overrideWithValue(tokens),
    clockProvider.overrideWithValue(() => now),
    apiClientProvider.overrideWith(
      (ref) => ApiClient(
        dio: Dio()..httpClientAdapter = http,
        tokenStore: tokens,
        authEvents: ref.watch(authEventsProvider),
        config: testConfig,
        platform: 'android',
        clock: () => now,
      ),
    ),
  ];

  ProviderContainer container() => ProviderContainer(overrides: overrides);
}

Map<String, dynamic> userJson({
  String? name = 'Asha',
  bool complete = true,
  List<String> roles = const ['customer'],
}) => {
  'id': '01M4JQSZSNAVTVCMS8A7AJ0USR',
  'name': name,
  'phone': '+919000000001',
  'email': null,
  'status': 'active',
  'roles': roles,
  'is_profile_complete': complete,
  'created_at': '2026-10-10T10:00:00Z',
};

Map<String, dynamic> sessionJson({bool newUser = false}) => {
  'data': {
    'token': '12|secret',
    'token_type': 'Bearer',
    'expires_at': '2027-01-08T10:00:00Z',
    'is_new_user': newUser,
    'user': userJson(name: newUser ? null : 'Asha', complete: !newUser),
  },
};

const errorUnauthenticated = {
  'error': {'code': 'UNAUTHENTICATED', 'message': 'Sign in.'},
};

Map<String, dynamic> summaryJson({
  String id = '01M4JQSZSNAVTVCMS8A7AJ0WJ9',
  String name = 'MG Road Metro Parking',
  double distanceKm = 0.42,
  String bookingMode = 'instant',
  String? hourly = '40.00',
  List<String> vehicles = const ['car'],
}) => {
  'id': id,
  'name': name,
  'address_line': '12 MG Road',
  'city': 'Bengaluru',
  'latitude': 12.9756,
  'longitude': 77.605,
  'distance_km': distanceKm,
  'booking_mode': bookingMode,
  'accepts_online_payment': true,
  'accepts_onsite_payment': true,
  'amenities': ['cctv'],
  'pools': [
    for (final code in vehicles)
      {
        'vehicle_type': {
          'code': code,
          'name': code == 'car' ? 'Car' : 'Two wheeler',
        },
        'hourly_rate': hourly,
        'daily_rate': null,
      },
  ],
  'from_hourly_rate': hourly,
  'currency': 'INR',
};

Map<String, dynamic> searchJson(
  List<Map<String, dynamic>> items, {
  int page = 1,
  int lastPage = 1,
}) => {
  'data': items,
  'meta': {
    'page': page,
    'per_page': 20,
    'total': items.length,
    'last_page': lastPage,
  },
};

Map<String, dynamic> lotJson({String timezone = 'Asia/Kolkata'}) => {
  'data': {
    'id': '01M4JQSZSNAVTVCMS8A7AJ0WJ9',
    'name': 'MG Road Metro Parking',
    'description': 'Secure parking beside the metro.',
    'address_line': '12 MG Road',
    'city': 'Bengaluru',
    'state': 'Karnataka',
    'postal_code': '560001',
    'latitude': 12.9756,
    'longitude': 77.605,
    'timezone': timezone,
    'booking_mode': 'owner_approval',
    'accepts_online_payment': true,
    'accepts_onsite_payment': false,
    'amenities': [
      {'code': 'cctv', 'name': 'CCTV'},
    ],
    'operating_hours': [
      {
        'day_of_week': 1,
        'is_closed': false,
        'opens_at': '00:00',
        'closes_at': '24:00',
      },
      {
        'day_of_week': 2,
        'is_closed': false,
        'opens_at': '06:00',
        'closes_at': '22:30',
      },
      {
        'day_of_week': 7,
        'is_closed': true,
        'opens_at': null,
        'closes_at': null,
      },
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
      {
        'id': '01M4JQSZT000000000000POOL2',
        'vehicle_type': {'code': 'two_wheeler', 'name': 'Two wheeler'},
        'allocation_mode': 'pooled',
        'capacity': 1,
        'is_active': true,
        'rates': [
          {'rate_type': 'hourly', 'amount': '15.00', 'currency': 'INR'},
        ],
      },
    ],
  },
};

Map<String, dynamic> quoteJson({String total = '80.00', int hours = 2}) => {
  'data': {
    'parking_lot_id': '01M4JQSZSNAVTVCMS8A7AJ0WJ9',
    'vehicle_type': 'car',
    'start_at': '2026-11-02T04:30:00Z',
    'end_at': '2026-11-02T06:30:00Z',
    'timezone': 'Asia/Kolkata',
    'booking_mode': 'owner_approval',
    'accepts_online_payment': true,
    'accepts_onsite_payment': false,
    'lines': [
      {
        'rate_type': 'hourly',
        'quantity': hours,
        'unit_amount': '40.00',
        'amount': total,
      },
    ],
    'base_amount': total,
    'total_amount': total,
    'currency': 'INR',
  },
};

Map<String, dynamic> availabilityJson({int left = 12}) => {
  'data': {
    'parking_lot_id': '01M4JQSZSNAVTVCMS8A7AJ0WJ9',
    'vehicle_type': 'car',
    'start_at': '2026-11-02T04:30:00Z',
    'end_at': '2026-11-02T06:30:00Z',
    'capacity': 40,
    'spaces_left': left,
    'is_within_operating_hours': true,
    'is_available': left > 0,
  },
};

const bookingId = '01M4JQYWW2WEFYAASEC49S6PW3';

Map<String, dynamic> bookingJson({
  String id = bookingId,
  String status = 'confirmed',
  String paymentMode = 'on_site',
  String reference = 'BK-K2M5XCN4',
  bool? refundEligible,
  String? approvalDeadline,
  String? paymentDeadline,
  String? checkedInAt,
}) => {
  'id': id,
  'reference': reference,
  'status': status,
  'booking_mode': status == 'pending_approval' ? 'owner_approval' : 'instant',
  'payment_mode': paymentMode,
  'payment_required': status == 'awaiting_payment',
  'parking_lot': {
    'id': '01M4JQSZSNAVTVCMS8A7AJ0WJ9',
    'name': 'MG Road Metro Parking',
  },
  'vehicle_type': 'car',
  'start_at': '2026-11-02T04:30:00Z',
  'end_at': '2026-11-02T06:30:00Z',
  'timezone': 'Asia/Kolkata',
  'price_lines': [
    {
      'rate_type': 'hourly',
      'quantity': 2,
      'unit_amount': '40.00',
      'amount': '80.00',
    },
  ],
  'base_amount': '80.00',
  'total_amount': '80.00',
  'currency': 'INR',
  'approval_deadline_at': approvalDeadline,
  'payment_deadline_at': paymentDeadline,
  'confirmed_at': status == 'confirmed' ? '2026-11-02T04:18:00Z' : null,
  'checked_in_at': checkedInAt,
  'checked_out_at': null,
  'cancelled_at': status == 'cancelled' ? '2026-11-02T04:20:00Z' : null,
  'cancellation_reason': null,
  'refund_eligible': refundEligible,
  'created_at': '2026-11-02T04:18:00Z',
};

Map<String, dynamic> bookingsJson(
  List<Map<String, dynamic>> items, {
  String? nextCursor,
}) => {
  'data': items,
  'meta': {
    'per_page': 20,
    'next_cursor': nextCursor,
    'has_more': nextCursor != null,
  },
};

Map<String, dynamic> orderJson({
  String status = 'created',
  String provider = 'razorpay',
  bool payable = true,
}) => {
  'id': '01M4JQSZSNAVTVCMS8A7AJ0ORD',
  'booking_id': bookingId,
  'status': status,
  'amount': '80.00',
  'currency': 'INR',
  'provider': provider,
  'checkout': !payable
      ? null
      : {
          'provider': provider,
          if (provider == 'razorpay') 'key_id': 'rzp_test_public',
          'order_id': 'order_abc',
          'amount_minor': 8000,
          'currency': 'INR',
          if (provider == 'razorpay') 'name': 'Parking Co',
          if (provider == 'razorpay') 'description': 'Booking BK-K2M5XCN4',
        },
  'expires_at': '2026-11-02T04:28:00Z',
  'paid_at': status == 'succeeded' ? '2026-11-02T04:19:00Z' : null,
};

Map<String, dynamic> paymentJson({
  String orderStatus = 'pending',
  String bookingStatus = 'awaiting_payment',
  String provider = 'razorpay',
}) => {
  'data': {
    'payment_mode': 'online',
    'booking_status': bookingStatus,
    'payment_required': bookingStatus == 'awaiting_payment',
    'order': orderJson(
      status: orderStatus,
      provider: provider,
      payable: orderStatus == 'created' || orderStatus == 'pending',
    ),
  },
};
