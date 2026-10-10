import 'package:app/core/api/api_error_code.dart';

/// The one failure type the rest of the app sees from the API layer.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    this.message,
    this.status,
    this.requestId,
    this.fieldErrors = const {},
    this.retryAfter,
  });

  /// Builds the exception from an error response body. Tolerates a body
  /// that is not the documented envelope (a proxy's HTML error page, for
  /// example) by reporting [ApiErrorCode.unknown].
  factory ApiException.fromResponse(
    Object? body, {
    int? status,
    Duration? retryAfter,
  }) {
    final error = body is Map ? body['error'] : null;
    if (error is! Map) {
      return ApiException(
        code: ApiErrorCode.unknown,
        status: status,
        retryAfter: retryAfter,
      );
    }

    final details = error['details'];
    final fieldErrors = <String, List<String>>{};
    if (details is Map) {
      details.forEach((key, value) {
        if (key is String && value is List) {
          fieldErrors[key] = value.whereType<String>().toList();
        }
      });
    }

    final message = error['message'];
    final requestId = error['request_id'];

    return ApiException(
      code: ApiErrorCode.fromWire(error['code']),
      message: message is String ? message : null,
      status: status,
      requestId: requestId is String ? requestId : null,
      fieldErrors: fieldErrors,
      retryAfter: retryAfter,
    );
  }

  final ApiErrorCode code;

  /// The API's English message. A fallback for display only; screens use
  /// their own text for the codes they handle.
  final String? message;

  final int? status;

  /// Shown on error screens so support can find the request.
  final String? requestId;

  /// Field name to messages, present on `VALIDATION_FAILED`.
  final Map<String, List<String>> fieldErrors;

  /// From the `Retry-After` header on `RATE_LIMITED`.
  final Duration? retryAfter;

  /// True when repeating the same request later can succeed.
  bool get isTransient => switch (code) {
    ApiErrorCode.network ||
    ApiErrorCode.timeout ||
    ApiErrorCode.serviceUnavailable ||
    ApiErrorCode.internalError ||
    ApiErrorCode.rateLimited ||
    ApiErrorCode.requestInProgress => true,
    _ => false,
  };

  @override
  String toString() =>
      'ApiException(${code.name}, status: $status, requestId: $requestId)';
}
