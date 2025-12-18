import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../widgets/nav_bar.dart';

class FriendsPage extends StatelessWidget {
  const FriendsPage({Key? key}) : super(key: key);

  void _onNavBarTap(BuildContext context, int index) {
    // Navigate based on selected index
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        // Already on Friends, no navigation needed
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/friend');
        break;
    }
  }

  /// Checks if friends are loaded from Firebase database
  /// Returns false until Firebase friends collection integration is implemented
  bool _areFriendsLoadedFromDatabase() {
    // TODO: Implement Firebase friends collection check
    // This will check if the logged-in user has friends loaded from Firebase
    return false;
  }

  /// Returns fallback friends when database collection is not loaded
  /// This serves as visual error handling for missing Firebase integration
  List<String> _getFallbackFriends() {
    return ['friend1', 'friend2', 'friend3'];
  }

  /// Builds a ListTile widget for a friend
  Widget _buildFriendTile(String friendName) {
    final initial = friendName.isNotEmpty ? friendName[0].toUpperCase() : '?';
    return ListTile(
      leading: CircleAvatar(
        child: Text(initial),
      ),
      title: Text(friendName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = AppConfigScope.of(context);
    // Check if friends are loaded from database
    final areFriendsLoaded = _areFriendsLoadedFromDatabase();

    // Get friends list - either from database or fallback
    final List<String> friendsList;
    if (areFriendsLoaded) {
      // TODO: Get friends from Firebase collection for logged-in user
      friendsList = []; // Placeholder for future Firebase integration
    } else {
      // Show fallback friends as visual error handling
      friendsList = _getFallbackFriends();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(config.appName),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: friendsList
            .map((friend) => _buildFriendTile(friend))
            .toList(),
      ),
      bottomNavigationBar: NavBar(
        currentIndex: 1, // Friends is at index 1
        onTap: (index) => _onNavBarTap(context, index),
      ),
    );
  }
}
