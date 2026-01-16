import 'package:flutter/material.dart';

import '../widgets/nav_bar.dart';
import '../widgets/google_maps_ui_widget.dart';
import '../widgets/user_menu_widget.dart';
import '../widgets/notification_bell.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLocationModalOpen = false;

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

  void _handleModalVisibilityChanged(bool isOpen) {
    if (isOpen != _isLocationModalOpen) {
      setState(() => _isLocationModalOpen = isOpen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final navBar = Align(
      key: const ValueKey('home-nav-bar'),
      alignment: Alignment.bottomCenter,
      child: NavBar(
        currentIndex: 0, // Home is at index 0
        onTap: (index) => _onNavBarTap(context, index),
        isFloating: true,
        isOnDarkBackground: true,
        activeColorOverride: const Color(0xFF00B030),
        inactiveColorOverride: const Color(0xFF00B030),
      ),
    );

    final mapsWidget = GoogleMapsUIWidget(
      key: const ValueKey('home-maps'),
      onModalVisibilityChanged: _handleModalVisibilityChanged,
    );

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: const [
          NotificationBell(
            isOnDarkBackground: true,
            iconColor: Color(0xFF00B030),
            badgeColor: Color(0xFF00B030),
          ),
          SizedBox(width: 8),
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: UserMenuWidget(
              isOnDarkBackground: true,
              iconColorOverride: Color(0xFF00B030),
              borderColorOverride: Color(0xFF00B030),
            ),
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
      body: Stack(
        children: _isLocationModalOpen
            ? [
                navBar,
                mapsWidget,
              ]
            : [
                mapsWidget,
                navBar,
              ],
      ),
    );
  }
}
