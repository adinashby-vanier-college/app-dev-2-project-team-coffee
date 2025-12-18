import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'config/app_config.dart';
import 'friendmap_app.dart';

Future<void> bootstrap(AppEnvironment environment) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final config = AppConfig.fromDefaults(environment);

  runApp(
    AppConfigScope(
      config: config,
      child: FriendmapApp(config: config),
    ),
  );
}
