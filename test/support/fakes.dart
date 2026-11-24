import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app/core/auth/token_store.dart';
import 'package:app/core/config/app_config.dart';
import 'package:app/core/files/picked_file.dart';
import 'package:app/core/location/location_service.dart';
import 'package:app/core/payment/checkout_launcher.dart';
import 'package:app/core/push/push_messaging.dart';
import 'package:app/core/scanning/qr_scanner.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

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
  String? registrationIntent;

  @override
  Future<StoredToken?> read() async => token;

  @override
  Future<void> write(StoredToken token) async => this.token = token;

  @override
  Future<String?> readRegistrationIntent() async => registrationIntent;

  @override
  Future<void> writeRegistrationIntent(String intent) async =>
      registrationIntent = intent;

  @override
  Future<void> clearRegistrationIntent() async => registrationIntent = null;

  @override
  Future<void> clear() async {
    token = null;
    registrationIntent = null;
  }
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
    Map<String, String>? headers,
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
            for (final entry in (headers ?? const <String, String>{}).entries)
              entry.key: [entry.value],
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
    // A gate pass nobody stubbed: the API has none, and the app falls back
    // to the plain code. Never takes an answer queued for something else.
    if (options.method == 'GET' && options.path.endsWith('/check-in-pass')) {
      return ResponseBody.fromString(
        jsonEncode({
          'error': {'code': 'NOT_FOUND', 'message': 'Not found.'},
        }),
        404,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    // Background lists nobody stubbed are empty, never taking an answer
    // queued for the step under test: the gate facilities on Profile and a
    // facility's attendants.
    if (options.method == 'GET' &&
        (options.path == '/gate/facilities' ||
            options.path.endsWith('/attendants'))) {
      return ResponseBody.fromString(
        jsonEncode({'data': <Object>[]}),
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

/// Stands in for the system file picker: hands back [next] (null = the
/// user cancelled) and records the extensions it was asked for.
class FakeFilePicker implements FilePickerService {
  PickedFile? next;

  /// Set to make the next pick fail the way the platform picker can.
  PickProblem? problem;
  final List<List<String>> asked = [];

  /// Whether each pick asked for the photo gallery.
  final List<bool> askedImages = [];

  @override
  Future<PickedFile?> pick({
    required List<String> extensions,
    bool images = false,
  }) async {
    asked.add(extensions);
    askedImages.add(images);
    final problem = this.problem;
    if (problem != null) {
      this.problem = null;
      throw PickException(problem);
    }
    return next;
  }
}

/// A small file of [sizeBytes] bytes.
PickedFile pickedFile(String name, {int sizeBytes = 2048}) =>
    PickedFile(name: name, bytes: Uint8List(sizeBytes));

/// Stands in for the payment provider's window: records what it was asked
/// to open and reports the outcome the test chose.
class FakeCheckoutLauncher implements CheckoutLauncher {
  FakeCheckoutLauncher([this.outcome = CheckoutOutcome.completed]);

  CheckoutOutcome outcome;

  /// Returned with [CheckoutOutcome.completed]; null like an external wallet.
  CheckoutReceipt? receipt;
  final List<CheckoutRequest> opened = [];

  @override
  Future<CheckoutResult> open(CheckoutRequest request) async {
    opened.add(request);
    return CheckoutResult(
      outcome,
      receipt: outcome == CheckoutOutcome.completed ? receipt : null,
    );
  }
}

/// The phone's location: a fixed [position], or [failure] when set.
class FakeLocationService implements LocationService {
  DevicePosition position = (latitude: 12.9352, longitude: 77.6245);
  LocationFailure? failure;
  int asked = 0;
  int settingsOpened = 0;

  @override
  Future<DevicePosition> current() async {
    asked++;
    final failure = this.failure;
    if (failure != null) throw LocationException(failure);
    return position;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

/// Firebase as the test sets it up. By default not configured, as in a
/// build without the Firebase files: nothing is registered or sent.
class FakePushMessaging implements PushMessaging {
  bool configured = false;
  bool allowed = true;
  String? currentToken = 'fcm-token-0000000000000001';
  int deleted = 0;
  PushData? launchedBy;
  final refreshes = StreamController<String>.broadcast();
  final opened = StreamController<PushData>.broadcast();
  final foreground = StreamController<PushData>.broadcast();

  @override
  Future<bool> start() async => configured;

  @override
  Future<bool> requestPermission() async => configured && allowed;

  @override
  Future<String?> token() async => configured ? currentToken : null;

  @override
  Stream<String> get tokenRefreshes => refreshes.stream;

  @override
  Stream<PushData> get openedMessages => opened.stream;

  @override
  Stream<PushData> get foregroundMessages => foreground.stream;

  @override
  Future<PushData?> launchMessage() async => launchedBy;

  @override
  Future<void> deleteToken() async => deleted++;

  Future<void> close() async {
    await refreshes.close();
    await opened.close();
    await foreground.close();
  }
}

/// The camera: returns [next] as if that QR code was scanned.
class FakeQrScanner implements QrScanner {
  String? next;
  int scans = 0;

  @override
  Future<String?> scan(BuildContext context) async {
    scans++;
    return next;
  }
}
