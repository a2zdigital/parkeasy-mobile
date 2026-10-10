/// Everything that differs between environments, read once at start-up.
/// Nothing else in the app reads an environment value.
///
/// These values are compiled into the app and can be extracted from it.
/// **Nothing secret belongs here.** See docs/conventions/security.md.
class AppConfig {
  const AppConfig._({
    required this.apiBaseUrl,
    required this.environment,
    required this.enablePaymentSimulation,
    required this.appVersion,
  });

  /// Reads the values passed with `--dart-define-from-file=env/<name>.json`.
  ///
  /// Throws a [StateError] with a message a developer can act on when the
  /// file was not passed or a value is wrong. The app must never start
  /// against a server nobody chose.
  factory AppConfig.fromEnvironment() => AppConfig.validated(
    apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    environment: const String.fromEnvironment('ENVIRONMENT'),
    enablePaymentSimulation: const bool.fromEnvironment(
      'ENABLE_PAYMENT_SIMULATION',
    ),
    appVersion: const String.fromEnvironment(
      'FLUTTER_BUILD_NAME',
      defaultValue: '0.0.0',
    ),
  );

  factory AppConfig.validated({
    required String apiBaseUrl,
    required String environment,
    bool enablePaymentSimulation = false,
    String appVersion = '0.0.0',
  }) {
    if (apiBaseUrl.isEmpty || environment.isEmpty) {
      throw StateError(
        'No environment was given. Run with '
        '--dart-define-from-file=env/local.json '
        '(copy env/local.example.json to create it).',
      );
    }

    final parsed = AppEnvironment.values.where((e) => e.name == environment);
    if (parsed.isEmpty) {
      throw StateError(
        'ENVIRONMENT must be one of '
        '${AppEnvironment.values.map((e) => e.name).join(', ')}; '
        'got "$environment".',
      );
    }

    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('API_BASE_URL is not a URL: "$apiBaseUrl".');
    }
    if (parsed.single != AppEnvironment.local && uri.scheme != 'https') {
      throw StateError('API_BASE_URL must use https outside local.');
    }
    if (parsed.single == AppEnvironment.production && enablePaymentSimulation) {
      throw StateError('Payment simulation cannot be enabled in production.');
    }

    return AppConfig._(
      apiBaseUrl: apiBaseUrl.replaceAll(RegExp(r'/+$'), ''),
      environment: parsed.single,
      enablePaymentSimulation: enablePaymentSimulation,
      appVersion: appVersion,
    );
  }

  /// Scheme and host of the API, without a trailing slash or `/api/v1`.
  final String apiBaseUrl;

  /// For display and reporting only. Behaviour never branches on it.
  final AppEnvironment environment;

  /// Shows the simulated-payment controls. True only where the API runs
  /// its fake payment provider.
  final bool enablePaymentSimulation;

  /// Sent to the API as `X-App-Version`.
  final String appVersion;

  /// The base of every versioned API call.
  String get apiV1 => '$apiBaseUrl/api/v1';
}

enum AppEnvironment { local, staging, production }
