import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'pages/chat_page.dart';
import 'pages/friends_page.dart';
import 'pages/home_page.dart';
import 'pages/phone_entry_screen.dart';
import 'pages/profile_page.dart';
import 'pages/sms_code_screen.dart';
import 'pages/moments_page.dart';
import 'pages/notifications_page.dart';
import 'providers/auth_provider.dart';
import 'providers/phone_auth_provider.dart';
import 'providers/saved_locations_provider.dart';
import 'providers/location_tracking_provider.dart';
import 'services/friends_service.dart';
import 'services/notification_service.dart';
import 'services/friend_request_manager.dart';
import 'services/phone_auth_service.dart';
import 'pages/landing_page.dart';

class FriendmapApp extends StatefulWidget {
  final AppConfig config;

  const FriendmapApp({super.key, required this.config});

  @override
  State<FriendmapApp> createState() => _FriendmapAppState();
}

class _FriendmapAppState extends State<FriendmapApp> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _notificationService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
            create: (_) => PhoneAuthProvider(PhoneAuthService())),
        ChangeNotifierProvider(create: (_) => SavedLocationsProvider()),
        ChangeNotifierProvider(create: (_) => LocationTrackingProvider()),
        ChangeNotifierProvider(
          create: (_) => FriendRequestManager(
            FriendsService(), // You might want to get this from GetIt if available, or just instance it
            _notificationService,
          ),
          lazy: false, // Ensure it starts listening immediately
        ),
      ],
      child: MaterialApp(
        title: widget.config.appName,
        debugShowCheckedModeBanner: !widget.config.environment.isProd,
        home: const LandingPage(),
        routes: {
          '/friends': (context) => const FriendsPage(),
          '/friend': (context) => const ChatPage(),
          '/home': (context) => const HomePage(),
          '/phone-entry': (context) => const PhoneEntryScreen(),
          '/profile': (context) => const ProfilePage(),
          '/sms-code': (context) => const SmsCodeScreen(),
          '/moments': (context) => const MomentsPage(),
          '/notifications': (context) => const NotificationsPage(),
        },
      ),
    );
  }
}

