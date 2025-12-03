import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/friends_page.dart';
import 'pages/chat_page.dart';

void main() {
  runApp(MaterialApp(
    home: const FriendsPage(),
    routes: {
      '/friends': (context) => const FriendsPage(),
      '/friend': (context) => const ChatPage(),
      '/home': (context) => const HomePage(),
    },
  ));
}
