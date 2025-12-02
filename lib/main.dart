import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/friends_page.dart';

void main() {
  runApp(MaterialApp(
    home: const HomePage(),  
    routes: {
      '/friends': (context) => const FriendsPage(),
    },
  ));
}
