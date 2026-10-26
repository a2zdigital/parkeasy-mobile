import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app/core/auth/token_store.dart';
import 'package:app/core/config/app_config.dart';
import 'package:app/core/payment/checkout_launcher.dart';
import 'package:dio/dio.dart';

final testConfig = AppConfig.validated(
  apiBaseUrl: 'http://api.test',
  environment: 'local',
  enablePaymentSimulation: true,
  appVersion: '1.2.3',
  searchLatitude: '12.9716',
  searchLongitude: '77.5946',
  searchLabel: 'Bengaluru',
  searchRadiusKm: '25',
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

  /// Standing answers by path, used for every GET of that path. They
  /// take precedence over the queue, so background loads (the Explore
  /// list) do not consume answers meant for the step under test.
  final Map<String, Object?> stubs = {};

  int _inFlight = 0;

  /// Completes when no request is in flight and none has started for a
  /// few consecutive checks: the code under test has finished reacting.
  /// Waits for the work itself, not for a fixed time, so it is as fast as
  /// the machine and never too short on a slow one.
  Future<void> idle() async {
    var quiet = 0;
    var seen = requests.length;
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (quiet < 4 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      if (_inFlight == 0 && requests.length == seen) {
        quiet++;
      } else {
        quiet = 0;
        seen = requests.length;
      }
    }
  }

  Future<void> waitForRequests(int count) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (requests.length < count && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    if (requests.length < count) {
      throw StateError(
        'Expected $count HTTP requests; got ${requests.length}.',
      );
    }
  }

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

  void respondLater(
    int status,
    Object? body, {
    required Completer<void> release,
  }) {
    _answers.add(
      _DeferredAnswer(
        ResponseBody.fromString(
          body is String ? body : jsonEncode(body),
          status,
          headers: {
            Headers.contentTypeHeader: [
              body is String ? 'text/html' : Headers.jsonContentType,
            ],
          },
        ),
        release.future,
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
    _inFlight++;
    try {
      return await _answer(options);
    } finally {
      _inFlight--;
    }
  }

  Future<ResponseBody> _answer(RequestOptions options) async {
    if (options.method == 'GET' && stubs.containsKey(options.path)) {
      return ResponseBody.fromString(
        jsonEncode(stubs[options.path]),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (_answers.isEmpty) {
      throw StateError('No fake answer queued for ${options.path}.');
    }
    final answer = _answers.removeAt(0);
    if (answer is _DeferredAnswer) {
      await answer.release;
      return answer.response;
    }
    if (answer is DioExceptionType) {
      throw DioException(requestOptions: options, type: answer);
    }
    return answer as ResponseBody;
  }

  @override
  void close({bool force = false}) {}
}

class _DeferredAnswer {
  const _DeferredAnswer(this.response, this.release);

  final ResponseBody response;
  final Future<void> release;
}

/// Stands in for the payment provider's window: records what it was asked
/// to open and reports the outcome the test chose.
class FakeCheckoutLauncher implements CheckoutLauncher {
  FakeCheckoutLauncher([this.outcome = CheckoutOutcome.completed]);

  CheckoutOutcome outcome;
  final List<CheckoutRequest> opened = [];

  @override
  Future<CheckoutOutcome> open(CheckoutRequest request) async {
    opened.add(request);
    return outcome;
  }
}
