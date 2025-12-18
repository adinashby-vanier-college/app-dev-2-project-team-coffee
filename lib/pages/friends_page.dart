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

  @override
  Widget build(BuildContext context) {
    final config = AppConfigScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(config.appName),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const ListTile(
            leading: CircleAvatar(child: Text('A')),
            title: Text('Alice'),
            subtitle: Text('Best friend'),
          ),
          ListTile(
            leading: CircleAvatar(child: Text('B')),
            title: Text('Bob'),
            subtitle: Text('Colleague'),
          ),
          ListTile(
            leading: CircleAvatar(child: Text('C')),
            title: Text('Charlie'),
            subtitle: Text('Gym buddy'),
          ),
        ],
      ),
      bottomNavigationBar: NavBar(
        currentIndex: 1, // Friends is at index 1
        onTap: (index) => _onNavBarTap(context, index),
      ),
    );
  }
}
