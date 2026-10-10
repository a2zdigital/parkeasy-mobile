import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiErrorCode', () {
    test('maps a documented code', () {
      expect(
        ApiErrorCode.fromWire('SLOT_UNAVAILABLE'),
        ApiErrorCode.slotUnavailable,
      );
    });

    test('maps anything else to unknown', () {
      expect(ApiErrorCode.fromWire('A_CODE_ADDED_LATER'), ApiErrorCode.unknown);
      expect(ApiErrorCode.fromWire(null), ApiErrorCode.unknown);
      expect(ApiErrorCode.fromWire(42), ApiErrorCode.unknown);
    });

    test('every API code is unique', () {
      final wires = ApiErrorCode.values.map((c) => c.wire).nonNulls.toList();

      expect(wires.toSet().length, wires.length);
    });
  });

  group('ApiException.fromResponse', () {
    test('reads the error envelope', () {
      final exception = ApiException.fromResponse({
        'error': {
          'code': 'VALIDATION_FAILED',
          'message': 'The given data was invalid.',
          'details': {
            'start_at': ['The start at field is required.'],
            'vehicle_type': ['Unknown vehicle type.', 'Second message.'],
          },
          'request_id': '01M4JQTFYJB2P74FSPQPSS37V9',
        },
      }, status: 422);

      expect(exception.code, ApiErrorCode.validationFailed);
      expect(exception.status, 422);
      expect(exception.requestId, '01M4JQTFYJB2P74FSPQPSS37V9');
      expect(exception.fieldErrors['start_at'], [
        'The start at field is required.',
      ]);
      expect(exception.fieldErrors['vehicle_type'], hasLength(2));
      expect(exception.isTransient, isFalse);
    });

    test('survives a body that is not the envelope', () {
      for (final body in [
        null,
        '<html>Bad gateway</html>',
        <Object?>[],
        {'error': 'x'},
      ]) {
        final exception = ApiException.fromResponse(body, status: 502);

        expect(exception.code, ApiErrorCode.unknown, reason: '$body');
        expect(exception.fieldErrors, isEmpty);
      }
    });

    test('ignores details of the wrong shape', () {
      final exception = ApiException.fromResponse({
        'error': {'code': 'VALIDATION_FAILED', 'details': <Object?>[]},
      });

      expect(exception.fieldErrors, isEmpty);
    });

    test('marks retryable failures as transient', () {
      const transient = ApiException(code: ApiErrorCode.network);
      const permanent = ApiException(code: ApiErrorCode.slotUnavailable);

      expect(transient.isTransient, isTrue);
      expect(permanent.isTransient, isFalse);
    });

    test('never prints the message, which may contain personal data', () {
      const exception = ApiException(
        code: ApiErrorCode.otpInvalid,
        message: 'Code for +919000000001 is wrong',
      );

      expect(exception.toString(), isNot(contains('+91')));
    });
  });
}
