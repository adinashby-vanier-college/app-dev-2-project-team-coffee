import 'package:flutter/material.dart';

import '../widgets/nav_bar.dart';
import '../widgets/css_map_widget.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _onNavBarTap(BuildContext context, int index) {
    // Navigate based on selected index
    switch (index) {
      case 0:
        // Already on Home, no navigation needed
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/friends');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/friend');
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
      body: const CssMapWidget(),
      bottomNavigationBar: NavBar(
        currentIndex: 0, // Home is at index 0
        onTap: (index) => _onNavBarTap(context, index),
      ),
    );
  }
}
