import 'bootstrap.dart';
import 'config/app_config.dart';

void main() {
  final env = AppEnvironmentX.from(
    const String.fromEnvironment('ENV', defaultValue: 'prod'),
    fallback: AppEnvironment.prod,
  );

  bootstrap(env);
}
