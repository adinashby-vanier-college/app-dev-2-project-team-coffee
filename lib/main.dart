import 'bootstrap.dart';
import 'config/app_config.dart';

void main() async {
  final env = AppEnvironmentX.from(
    const String.fromEnvironment('ENV', defaultValue: 'prod'),
    fallback: AppEnvironment.prod,
  );

  await bootstrap(env);
}
