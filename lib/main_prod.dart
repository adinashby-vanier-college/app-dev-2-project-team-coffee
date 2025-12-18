import 'bootstrap.dart';
import 'config/app_config.dart';

void main() async {
  await bootstrap(AppEnvironment.prod);
}
