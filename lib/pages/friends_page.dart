import 'package:flutter/material.dart';

class FriendsPage extends StatelessWidget {
  const FriendsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          ListTile(
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
    );
  }
}
