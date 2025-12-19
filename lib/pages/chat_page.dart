import 'package:flutter/material.dart';

import '../widgets/nav_bar.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  void _onNavBarTap(BuildContext context, int index) {
    // Navigate based on selected index
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/friends');
        break;
      case 2:
        // Already on Chat, no navigation needed
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Image.asset(
            'lib/assets/FriendMap.png',
            height: 25,
            fit: BoxFit.contain,
          ),
        ),
        centerTitle: false,
      ),
      body: const Center(
        child: Text(
          'Chat',
          style: TextStyle(fontSize: 24),
        ),
      ),
      bottomNavigationBar: NavBar(
        currentIndex: 2, // Chat is at index 2
        onTap: (index) => _onNavBarTap(context, index),
      ),
    );
  }
}
