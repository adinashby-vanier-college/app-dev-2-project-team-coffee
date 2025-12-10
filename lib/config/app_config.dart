import 'package:flutter/widgets.dart';

enum AppEnvironment { dev, prod }

extension AppEnvironmentX on AppEnvironment {
  String get name => this == AppEnvironment.prod ? 'prod' : 'dev';
  bool get isProd => this == AppEnvironment.prod;
  bool get isDev => this == AppEnvironment.dev;

  static AppEnvironment from(String raw, {required AppEnvironment fallback}) {
    switch (raw.toLowerCase()) {
      case 'prod':
        return AppEnvironment.prod;
      case 'dev':
        return AppEnvironment.dev;
      default:
        return fallback;
    }
  }
}

class AppConfig {
  final AppEnvironment environment;
  final String appName;
  final String apiBaseUrl;

  const AppConfig({
    required this.environment,
    required this.appName,
    required this.apiBaseUrl,
  });

  factory AppConfig.fromDefaults(AppEnvironment fallback) {
    final envOverride = const String.fromEnvironment('ENV', defaultValue: '');
    final resolvedEnv = AppEnvironmentX.from(envOverride, fallback: fallback);

    final defaultAppName = resolvedEnv.isProd ? 'Friendmap' : 'Friendmap (Dev)';
    final defaultApiBaseUrl = resolvedEnv.isProd
        ? 'https://api.example.com'
        : 'https://dev.api.example.com';

    final appNameDefine = const String.fromEnvironment(
      'APP_NAME',
      defaultValue: '',
    );
    final apiBaseUrlDefine = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );

    return AppConfig(
      environment: resolvedEnv,
      appName: appNameDefine.isEmpty ? defaultAppName : appNameDefine,
      apiBaseUrl: apiBaseUrlDefine.isEmpty
          ? defaultApiBaseUrl
          : apiBaseUrlDefine,
    );
  }
}

class AppConfigScope extends InheritedWidget {
  final AppConfig config;

  const AppConfigScope({super.key, required this.config, required super.child});

  static AppConfig of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppConfigScope>();
    assert(scope != null, 'AppConfigScope not found in widget tree');
    return scope!.config;
  }

  @override
  bool updateShouldNotify(covariant AppConfigScope oldWidget) {
    return oldWidget.config != config;
  }
}
