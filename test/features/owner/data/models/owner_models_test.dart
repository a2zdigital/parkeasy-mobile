import 'package:app/features/booking/data/models/payment_mode.dart';
import 'package:app/features/owner/data/models/approval_status.dart';
import 'package:app/features/owner/data/models/earning_entry.dart';
import 'package:app/features/owner/data/models/earning_kind.dart';
import 'package:app/features/owner/data/models/onsite_collection_state.dart';
import 'package:app/features/owner/data/models/operating_hour_input.dart';
import 'package:app/features/owner/data/models/owner_earnings.dart';
import 'package:app/features/owner/data/models/owner_parking_lot.dart';
import 'package:app/features/owner/data/models/parking_lot_input.dart';
import 'package:app/features/owner/data/models/parking_lot_options.dart';
import 'package:app/features/owner/data/models/parking_owner.dart';
import 'package:app/features/owner/data/models/verification_status.dart';
import 'package:app/features/parking_lot/data/models/booking_mode.dart';
import 'package:app/features/parking_lot/data/models/rate_type.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../parking_lot/data/models/parking_lot_test.dart' show lotJson;

void main() {
  test('OwnerParkingLot reads the facility and its review from one object', () {
    final owned = OwnerParkingLot.fromJson({
      ...lotJson(),
      'approval_status': 'rejected',
      'rejection_reason': 'Address could not be verified.',
      'is_active': false,
      'submitted_at': '2026-10-09T08:00:00Z',
      'reviewed_at': '2026-10-10T08:00:00Z',
      'created_at': '2026-10-08T08:00:00Z',
      'updated_at': '2026-10-10T08:00:00Z',
    });

    expect(owned.lot.name, 'MG Road Metro Parking');
    expect(owned.lot.pools, hasLength(1));
    expect(owned.approvalStatus, ApprovalStatus.rejected);
    expect(owned.rejectionReason, 'Address could not be verified.');
    expect(owned.reviewedAt, DateTime.utc(2026, 10, 10, 8));
  });

  test('ParkingOwner parses a pending application', () {
    final owner = ParkingOwner.fromJson({
      'id': '01M4JQSZSNAVTVCMS8A7AJ0OWN',
      'business_name': 'City Parking Services',
      'contact_phone': '+919000000004',
      'verification_status': 'pending',
      'rejection_reason': null,
      'verified_at': null,
      'created_at': '2026-10-10T10:00:00Z',
    });

    expect(owner.verificationStatus, VerificationStatus.pending);
    expect(owner.verifiedAt, isNull);
  });

  test('ParkingLotOptions parses the choices', () {
    final options = ParkingLotOptions.fromJson({
      'default_booking_mode': 'instant',
      'selectable_booking_modes': ['instant', 'owner_approval', 'auction'],
      'rate_types': ['hourly', 'daily'],
      'vehicle_types': [
        {'code': 'car', 'name': 'Car'},
      ],
      'amenities': [
        {'code': 'cctv', 'name': 'CCTV'},
      ],
      'default_timezone': 'Asia/Kolkata',
      'currency': 'INR',
    });

    expect(options.selectableBookingModes, [
      BookingMode.instant,
      BookingMode.ownerApproval,
      BookingMode.unknown,
    ]);
    expect(options.rateTypes, [RateType.hourly, RateType.daily]);
    expect(options.vehicleTypes.single.name, 'Car');
  });

  test('OwnerEarnings parses both sides of the position', () {
    final earnings = OwnerEarnings.fromJson({
      'currency': 'INR',
      'payable_balance': '136.00',
      'commission_owed': '18.00',
      'online': {
        'collected': '160.00',
        'commission': '24.00',
        'earned': '136.00',
        'refunded': '0.00',
      },
      'on_site': {'collected': '120.00', 'commission': '18.00'},
    });

    expect(earnings.payable.toWire(), '136.00');
    expect(earnings.owed.toWire(), '18.00');
    expect(earnings.online.earned, Decimal.parse('136'));
    expect(earnings.onSite.collected, Decimal.parse('120'));
  });

  test('EarningEntry keeps the commission rate exact', () {
    final entry = EarningEntry.fromJson({
      'id': '01M4JQSZSNAVTVCMS8A7AJ0ENT',
      'booking_id': '01M4JQYWW2WEFYAASEC49S6PW3',
      'kind': 'owed_onsite',
      'base_amount': '120.00',
      'commission_rate': '12.5',
      'commission_amount': '15.00',
      'owner_amount': '105.00',
      'currency': 'INR',
      'created_at': '2026-10-10T11:07:52Z',
    });

    expect(entry.kind, EarningKind.owedOnsite);
    expect(entry.commissionRate, Decimal.parse('12.5'));
  });

  test('OnsiteCollectionState parses before and after collection', () {
    Map<String, dynamic> state(Object? collection) => {
      'payment_mode': 'on_site',
      'amount_due': '80.00',
      'currency': 'INR',
      'collection': collection,
    };

    final before = OnsiteCollectionState.fromJson(state(null));
    final after = OnsiteCollectionState.fromJson(
      state({
        'id': '01M4JQYWXV4GAZN31RS8CNH55N',
        'booking_id': '01M4JQYWW2WEFYAASEC49S6PW3',
        'amount': '80.00',
        'currency': 'INR',
        'collected_at': '2026-10-10T11:07:52Z',
      }),
    );

    expect(before.paymentMode, PaymentMode.onSite);
    expect(before.due.toWire(), '80.00');
    expect(before.collection, isNull);
    expect(after.collection?.total.toWire(), '80.00');
  });

  group('inputs', () {
    test('a partial facility update sends only what was set', () {
      final json = const ParkingLotInput(
        name: 'New name',
        bookingMode: BookingMode.ownerApproval,
        acceptsOnsitePayment: false,
      ).toJson();

      expect(json, {
        'name': 'New name',
        'booking_mode': 'owner_approval',
        'accepts_onsite_payment': false,
      });
    });

    test('a closed day is sent without times', () {
      final json = const OperatingHourInput(
        dayOfWeek: 7,
        isClosed: true,
      ).toJson();

      expect(json, {'day_of_week': 7, 'is_closed': true});
    });
  });
}
