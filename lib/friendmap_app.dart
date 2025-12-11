import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'pages/chat_page.dart';
import 'pages/friends_page.dart';
import 'pages/home_page.dart';
import 'pages/phone_entry_screen.dart';
import 'pages/sms_code_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/phone_auth_provider.dart';
import 'services/phone_auth_service.dart';

class FriendmapApp extends StatelessWidget {
  final AppConfig config;

  const FriendmapApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
            create: (_) => PhoneAuthProvider(PhoneAuthService())),
      ],
      child: MaterialApp(
        title: config.appName,
        debugShowCheckedModeBanner: !config.environment.isProd,
        home: const FriendsPage(),
        routes: {
          '/friends': (context) => const FriendsPage(),
          '/friend': (context) => const ChatPage(),
          '/home': (context) => const HomePage(),
          '/phone-entry': (context) => const PhoneEntryScreen(),
          '/sms-code': (context) => const SmsCodeScreen(),
        },
      ),
    );
  }
}
