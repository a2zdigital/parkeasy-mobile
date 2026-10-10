import 'package:app/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

AppConfig config({
  String apiBaseUrl = 'http://10.0.2.2:8000/',
  String environment = 'local',
  bool enablePaymentSimulation = false,
  String latitude = '12.9716',
  String longitude = '77.5946',
  String label = 'Bengaluru',
  String radius = '25',
}) => AppConfig.validated(
  apiBaseUrl: apiBaseUrl,
  environment: environment,
  enablePaymentSimulation: enablePaymentSimulation,
  searchLatitude: latitude,
  searchLongitude: longitude,
  searchLabel: label,
  searchRadiusKm: radius,
);

void main() {
  test('builds the versioned API base and trims a trailing slash', () {
    final local = config();

    expect(local.apiV1, 'http://10.0.2.2:8000/api/v1');
    expect(local.environment, AppEnvironment.local);
    expect(local.enablePaymentSimulation, isFalse);
  });

  test('refuses to start when no environment file was passed', () {
    expect(
      () => config(apiBaseUrl: '', environment: ''),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('--dart-define-from-file'),
        ),
      ),
    );
    expect(AppConfig.fromEnvironment, throwsStateError);
  });

  test('refuses an unknown environment name or a value that is not a URL', () {
    expect(
      () => config(apiBaseUrl: 'http://x.test', environment: 'qa'),
      throwsStateError,
    );
    expect(() => config(apiBaseUrl: 'localhost'), throwsStateError);
  });

  test('requires https outside local', () {
    for (final environment in ['staging', 'production']) {
      expect(
        () => config(
          apiBaseUrl: 'http://api.example.test',
          environment: environment,
        ),
        throwsStateError,
        reason: environment,
      );
    }
    expect(
      config(
        apiBaseUrl: 'https://api.example.test',
        environment: 'staging',
      ).environment,
      AppEnvironment.staging,
    );
  });

  test('payment simulation can never be on in production', () {
    expect(
      () => config(
        apiBaseUrl: 'https://api.example.test',
        environment: 'production',
        enablePaymentSimulation: true,
      ),
      throwsStateError,
    );
  });

  test('carries the search origin and radius', () {
    final local = config();

    expect(local.searchOrigin.latitude, 12.9716);
    expect(local.searchOrigin.label, 'Bengaluru');
    expect(local.searchRadiusKm, 25);
  });

  test(
    'refuses a search origin that is not a real place, or a radius the API rejects',
    () {
      expect(() => config(latitude: '120'), throwsStateError);
      expect(() => config(longitude: 'east'), throwsStateError);
      expect(() => config(label: ''), throwsStateError);
      expect(() => config(radius: '80'), throwsStateError);
      expect(() => config(radius: '0'), throwsStateError);
    },
  );
}
