import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'friendmap_app.dart';

void bootstrap(AppEnvironment environment) {
  final config = AppConfig.fromDefaults(environment);

  runApp(
    AppConfigScope(
      config: config,
      child: FriendmapApp(config: config),
    ),
  );
}
