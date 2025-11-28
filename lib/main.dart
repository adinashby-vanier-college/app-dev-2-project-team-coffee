import 'package:flutter/material.dart';
import 'pages/home_page.dart';
//import 'pages/friends_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FriendMap',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        //'/friends': (context) => const FriendsPage(),
      },
    );
  }
}