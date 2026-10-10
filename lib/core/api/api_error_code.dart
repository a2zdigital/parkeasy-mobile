/// Every error code the API documents, plus the failures that happen
/// before a response exists. Screens branch on this, never on a message.
///
/// A code the app does not know yet becomes [unknown]: the API may add
/// codes before the app is updated.
enum ApiErrorCode {
  // General
  validationFailed('VALIDATION_FAILED'),
  invalidQueryParameter('INVALID_QUERY_PARAMETER'),
  malformedRequest('MALFORMED_REQUEST'),
  unauthenticated('UNAUTHENTICATED'),
  forbidden('FORBIDDEN'),
  notFound('NOT_FOUND'),
  methodNotAllowed('METHOD_NOT_ALLOWED'),
  conflict('CONFLICT'),
  idempotencyKeyRequired('IDEMPOTENCY_KEY_REQUIRED'),
  idempotencyKeyReused('IDEMPOTENCY_KEY_REUSED'),
  requestInProgress('REQUEST_IN_PROGRESS'),
  rateLimited('RATE_LIMITED'),
  appUpdateRequired('APP_UPDATE_REQUIRED'),
  apiVersionRetired('API_VERSION_RETIRED'),
  serviceUnavailable('SERVICE_UNAVAILABLE'),
  internalError('INTERNAL_ERROR'),

  // Identity
  otpInvalid('OTP_INVALID'),
  otpExpired('OTP_EXPIRED'),
  otpAttemptsExceeded('OTP_ATTEMPTS_EXCEEDED'),
  otpDeliveryFailed('OTP_DELIVERY_FAILED'),
  accountSuspended('ACCOUNT_SUSPENDED'),

  // Parking
  ownerNotVerified('OWNER_NOT_VERIFIED'),
  ownerProfileNotFound('OWNER_PROFILE_NOT_FOUND'),
  ownerApplicationExists('OWNER_APPLICATION_EXISTS'),
  invalidReviewState('INVALID_REVIEW_STATE'),
  parkingLotIncomplete('PARKING_LOT_INCOMPLETE'),
  parkingLotUnderReview('PARKING_LOT_UNDER_REVIEW'),
  inventoryPoolExists('INVENTORY_POOL_EXISTS'),
  parkingLotLocationLocked('PARKING_LOT_LOCATION_LOCKED'),

  // Availability and quote
  parkingLotNotBookable('PARKING_LOT_NOT_BOOKABLE'),
  outsideOperatingHours('OUTSIDE_OPERATING_HOURS'),
  vehicleTypeNotSupported('VEHICLE_TYPE_NOT_SUPPORTED'),
  invalidBookingWindow('INVALID_BOOKING_WINDOW'),

  // Booking
  slotUnavailable('SLOT_UNAVAILABLE'),
  quoteExpired('QUOTE_EXPIRED'),
  approvalRequired('APPROVAL_REQUIRED'),
  approvalExpired('APPROVAL_EXPIRED'),
  bookingExpired('BOOKING_EXPIRED'),
  invalidBookingState('INVALID_BOOKING_STATE'),
  cancellationNotAllowed('CANCELLATION_NOT_ALLOWED'),
  checkInNotAllowed('CHECK_IN_NOT_ALLOWED'),
  checkOutNotAllowed('CHECK_OUT_NOT_ALLOWED'),

  // Payment
  paymentPending('PAYMENT_PENDING'),
  paymentNotRequired('PAYMENT_NOT_REQUIRED'),
  paymentAlreadyCompleted('PAYMENT_ALREADY_COMPLETED'),
  paymentModeNotSupported('PAYMENT_MODE_NOT_SUPPORTED'),
  paymentProviderUnavailable('PAYMENT_PROVIDER_UNAVAILABLE'),
  refundNotAllowed('REFUND_NOT_ALLOWED'),
  onsiteCollectionNotAllowed('ONSITE_COLLECTION_NOT_ALLOWED'),
  onsiteCollectionExists('ONSITE_COLLECTION_EXISTS'),

  // Raised by the app, not the API
  network(null),
  timeout(null),
  unknown(null);

  const ApiErrorCode(this.wire);

  /// The code as the API writes it; null for the app's own codes.
  final String? wire;

  static final Map<String, ApiErrorCode> _byWire = {
    for (final code in values)
      if (code.wire != null) code.wire!: code,
  };

  static ApiErrorCode fromWire(Object? value) =>
      _byWire[value] ?? ApiErrorCode.unknown;
}
