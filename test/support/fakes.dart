import 'dart:convert';
import 'dart:typed_data';

import 'package:app/core/auth/token_store.dart';
import 'package:app/core/config/app_config.dart';
import 'package:dio/dio.dart';

final testConfig = AppConfig.validated(
  apiBaseUrl: 'http://api.test',
  environment: 'local',
  enablePaymentSimulation: true,
  appVersion: '1.2.3',
);

class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this.token]);

  StoredToken? token;

  @override
  Future<StoredToken?> read() async => token;

  @override
  Future<void> write(StoredToken token) async => this.token = token;

  @override
  Future<void> clear() async => token = null;
}

StoredToken validToken([String value = 'token-1']) =>
    StoredToken(value: value, expiresAt: DateTime.utc(2099));

/// Answers HTTP requests from a queue and records what was sent, so tests
/// never reach a network.
class FakeHttpAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final List<Object> _answers = [];

  void respond(int status, Object? body, {Map<String, String>? headers}) {
    _answers.add(
      ResponseBody.fromString(
        body is String ? body : jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [
            body is String ? 'text/html' : Headers.jsonContentType,
          ],
          for (final entry in (headers ?? const <String, String>{}).entries)
            entry.key: [entry.value],
        },
      ),
    );
  }

  void fail(DioExceptionType type) => _answers.add(type);

  RequestOptions get last => requests.last;

  Object? get lastBody {
    final data = last.data;
    return data is String ? jsonDecode(data) : data;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_answers.isEmpty) {
      throw StateError('No fake answer queued for ${options.path}.');
    }
    final answer = _answers.removeAt(0);
    if (answer is DioExceptionType) {
      throw DioException(requestOptions: options, type: answer);
    }
    return answer as ResponseBody;
  }

  @override
  void close({bool force = false}) {}
}
