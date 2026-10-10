import 'package:app/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds the versioned API base and trims a trailing slash', () {
    final config = AppConfig.validated(
      apiBaseUrl: 'http://10.0.2.2:8000/',
      environment: 'local',
    );

    expect(config.apiV1, 'http://10.0.2.2:8000/api/v1');
    expect(config.environment, AppEnvironment.local);
    expect(config.enablePaymentSimulation, isFalse);
  });

  test('refuses to start when no environment file was passed', () {
    expect(
      () => AppConfig.validated(apiBaseUrl: '', environment: ''),
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
      () => AppConfig.validated(apiBaseUrl: 'http://x.test', environment: 'qa'),
      throwsStateError,
    );
    expect(
      () => AppConfig.validated(apiBaseUrl: 'localhost', environment: 'local'),
      throwsStateError,
    );
  });

  test('requires https outside local', () {
    for (final environment in ['staging', 'production']) {
      expect(
        () => AppConfig.validated(
          apiBaseUrl: 'http://api.example.test',
          environment: environment,
        ),
        throwsStateError,
        reason: environment,
      );
    }
    expect(
      AppConfig.validated(
        apiBaseUrl: 'https://api.example.test',
        environment: 'staging',
      ).environment,
      AppEnvironment.staging,
    );
  });

  test('payment simulation can never be on in production', () {
    expect(
      () => AppConfig.validated(
        apiBaseUrl: 'https://api.example.test',
        environment: 'production',
        enablePaymentSimulation: true,
      ),
      throwsStateError,
    );
  });
}
