import 'package:flutter/material.dart';

import '../widgets/nav_bar.dart';
import '../widgets/google_maps_ui_widget.dart';
import '../widgets/user_menu_widget.dart';
import '../widgets/notification_bell.dart';

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
        Navigator.pushReplacementNamed(context, '/moments');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/friend');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: const [
          NotificationBell(),
          SizedBox(width: 8),
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: UserMenuWidget(),
          ),
        ],
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
      body: const GoogleMapsUIWidget(),
      bottomNavigationBar: NavBar(
        currentIndex: 0, // Home is at index 0
        onTap: (index) => _onNavBarTap(context, index),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
