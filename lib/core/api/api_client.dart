import 'dart:io' show HttpHeaders;

import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/auth/auth_events.dart';
import 'package:app/core/auth/token_store.dart';
import 'package:app/core/config/app_config.dart';
import 'package:dio/dio.dart';

/// The only class that talks HTTP. Repositories call it; nothing else
/// imports `dio`.
///
/// It adds the standard headers and the token, and turns every failure
/// into an [ApiException]. It never logs a request or a response.
class ApiClient {
  ApiClient({
    required Dio dio,
    required TokenStore tokenStore,
    required AuthEvents authEvents,
    required AppConfig config,
    required String platform,
    DateTime Function()? clock,
  }) : _dio = dio,
       _tokenStore = tokenStore,
       _authEvents = authEvents,
       _clock = clock ?? DateTime.now {
    _dio.options
      ..baseUrl = config.apiV1
      ..connectTimeout = const Duration(seconds: 10)
      ..sendTimeout = const Duration(seconds: 20)
      ..receiveTimeout = const Duration(seconds: 20)
      ..responseType = ResponseType.json
      ..headers = {
        HttpHeaders.acceptHeader: 'application/json',
        'X-App-Version': config.appVersion,
        'X-App-Platform': platform,
      };
  }

  static const idempotencyHeader = 'Idempotency-Key';

  final Dio _dio;
  final TokenStore _tokenStore;
  final AuthEvents _authEvents;
  final DateTime Function() _clock;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, Object?>? query,
  }) => _send('GET', path, query: query);

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    String? idempotencyKey,
    void Function()? onRequestPrepared,
  }) => _send(
    'POST',
    path,
    body: body,
    idempotencyKey: idempotencyKey,
    onRequestPrepared: onRequestPrepared,
  );

  Future<Map<String, dynamic>> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<Map<String, dynamic>> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  /// The `data` object of a response, for endpoints that return one item.
  static Map<String, dynamic> object(Map<String, dynamic> envelope) {
    final data = envelope['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw const ApiException(code: ApiErrorCode.unknown);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    String? idempotencyKey,
    void Function()? onRequestPrepared,
  }) async {
    final token = await _tokenStore.read();
    final headers = <String, Object?>{
      if (token != null && !token.isExpiredAt(_clock().toUtc()))
        HttpHeaders.authorizationHeader: 'Bearer ${token.value}',
      if (idempotencyKey != null) idempotencyHeader: idempotencyKey,
    };

    try {
      onRequestPrepared?.call();
      final response = await _dio.request<Object?>(
        path,
        data: body,
        queryParameters: _withoutNulls(query),
        options: Options(
          method: method,
          headers: headers,
          contentType: body == null ? null : Headers.jsonContentType,
        ),
      );

      final data = response.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      // A success with no JSON object (for example 204) is an empty envelope.
      return const <String, dynamic>{};
    } on DioException catch (error) {
      final exception = _toApiException(error);
      if (exception.code == ApiErrorCode.unauthenticated && token != null) {
        _authEvents.reportUnauthenticated();
      }
      throw exception;
    }
  }

  ApiException _toApiException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(code: ApiErrorCode.timeout);
      case DioExceptionType.connectionError:
        return const ApiException(code: ApiErrorCode.network);
      case DioExceptionType.badResponse:
        final response = error.response;
        return ApiException.fromResponse(
          response?.data,
          status: response?.statusCode,
          retryAfter: _retryAfter(response),
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return ApiException(
          code: error.error is FormatException
              ? ApiErrorCode.unknown
              : ApiErrorCode.network,
        );
    }
  }

  static Duration? _retryAfter(Response<Object?>? response) {
    final seconds = int.tryParse(
      response?.headers.value(HttpHeaders.retryAfterHeader) ?? '',
    );
    return seconds == null ? null : Duration(seconds: seconds);
  }

  static Map<String, Object?>? _withoutNulls(Map<String, Object?>? query) {
    if (query == null) return null;
    return {
      for (final entry in query.entries)
        if (entry.value != null) entry.key: entry.value,
    };
  }
}
