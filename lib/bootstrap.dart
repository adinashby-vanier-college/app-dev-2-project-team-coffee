import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';

import 'config/app_config.dart';
import 'friendmap_app.dart';

import 'utils/locations_initializer.dart';

Future<void> bootstrap(AppEnvironment environment) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Firestore offline persistence
  try {
    await FirebaseFirestore.instance.enablePersistence(
      const PersistenceSettings(synchronizeTabs: true),
    );
    debugPrint('Firestore offline persistence enabled');
  } catch (e) {
    // On web or if already enabled, this may fail - that's okay
    debugPrint('Firestore persistence setup: $e');
  }

  // Initialize locations if they don't exist
  // Note: This requires authentication. If locations need to be uploaded initially,
  // use the script at lib/scripts/upload_locations.dart instead
  try {
    final locationsInitializer = LocationsInitializer();
    final exists = await locationsInitializer.locationsExist();
    if (!exists) {
      // Check if user is authenticated before attempting to upload
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        debugPrint('Initializing locations...');
        final count = await locationsInitializer.initializeLocations();
        debugPrint('Successfully initialized $count locations');
      } else {
        debugPrint('Skipping location initialization: User not authenticated. '
            'Locations should be uploaded via lib/scripts/upload_locations.dart');
      }
    } else {
      debugPrint('Locations already initialized');
    }
  } catch (e) {
    debugPrint('Error initializing locations: $e');
  }
  
  final config = AppConfig.fromDefaults(environment);

  runApp(
    AppConfigScope(
      config: config,
      child: FriendmapApp(config: config),
    ),
  );
}
