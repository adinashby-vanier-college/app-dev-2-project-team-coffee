import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'pages/chat_page.dart';
import 'pages/friends_page.dart';
import 'pages/home_page.dart';

class FriendmapApp extends StatelessWidget {
  final AppConfig config;

  const FriendmapApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: config.appName,
      debugShowCheckedModeBanner: !config.environment.isProd,
      home: const FriendsPage(),
      routes: {
        '/friends': (context) => const FriendsPage(),
        '/friend': (context) => const ChatPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}
