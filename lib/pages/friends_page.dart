import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/friends_service.dart' show FriendsService, FriendRequest;
import '../services/user_profile_service.dart';
import '../widgets/nav_bar.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({Key? key}) : super(key: key);

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final FriendsService _friendsService = FriendsService();
  final UserProfileService _userProfileService = UserProfileService();
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onNavBarTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/friend');
        break;
    }
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _userProfileService.searchUsersByEmail(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching users: $e')),
        );
      }
    }
  }

  Future<void> _sendFriendRequest(String toUid) async {
    try {
      await _friendsService.sendFriendRequest(toUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent')),
        );
        setState(() {
          _searchResults = [];
          _searchController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _acceptFriendRequest(String requestId) async {
    try {
      await _friendsService.acceptFriendRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request accepted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _declineFriendRequest(String requestId) async {
    try {
      await _friendsService.declineFriendRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request declined')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildFriendRequestTile(FriendRequest request, UserModel? fromUser) {
    final displayName = fromUser?.name ?? fromUser?.email ?? 'Unknown User';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(initial),
        ),
        title: Text(displayName),
        subtitle: Text(fromUser?.email ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () => _acceptFriendRequest(request.id),
              tooltip: 'Accept',
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => _declineFriendRequest(request.id),
              tooltip: 'Decline',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendTile(UserModel friend) {
    final displayName = friend.name ?? friend.email ?? 'Unknown User';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(initial),
        ),
        title: Text(displayName),
        subtitle: Text(friend.email ?? ''),
      ),
    );
  }

  Widget _buildSearchResultTile(UserModel user) {
    final displayName = user.name ?? user.email ?? 'Unknown User';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(initial),
        ),
        title: Text(displayName),
        subtitle: Text(user.email ?? ''),
        trailing: IconButton(
          icon: const Icon(Icons.person_add),
          onPressed: () => _sendFriendRequest(user.uid),
          tooltip: 'Send friend request',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = AppConfigScope.of(context);
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(config.appName),
        ),
        body: const Center(
          child: Text('Please sign in to view friends'),
        ),
        bottomNavigationBar: NavBar(
          currentIndex: 1,
          onTap: (index) => _onNavBarTap(context, index),
        ),
      );
    }

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
      body: Column(
        children: [
          // Search section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search users by email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _searchUsers(),
                  ),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: _isSearching ? null : _searchUsers,
                  child: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Search'),
                ),
              ],
            ),
          ),

          // Search results
          if (_searchResults.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Search Results',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        return _buildSearchResultTile(_searchResults[index]);
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Friend requests and friends
          if (_searchResults.isEmpty)
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Friend Requests'),
                        Tab(text: 'Friends'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Friend requests tab
                          StreamBuilder<List<FriendRequest>>(
                            stream: _friendsService.getPendingFriendRequests(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (snapshot.hasError) {
                                return Center(
                                  child: Text('Error: ${snapshot.error}'),
                                );
                              }

                              final requests = snapshot.data ?? [];

                              if (requests.isEmpty) {
                                return const Center(
                                  child: Text('No pending friend requests'),
                                );
                              }

                              return FutureBuilder<List<UserModel?>>(
                                future: Future.wait(
                                  requests.map((req) =>
                                      _userProfileService.getUserByUid(
                                          req.fromUid)),
                                ),
                                builder: (context, userSnapshot) {
                                  if (userSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }

                                  final users = userSnapshot.data ?? [];

                                  return ListView.builder(
                                    padding: const EdgeInsets.all(16.0),
                                    itemCount: requests.length,
                                    itemBuilder: (context, index) {
                                      final request = requests[index];
                                      final fromUser = index < users.length
                                          ? users[index]
                                          : null;
                                      return _buildFriendRequestTile(
                                          request, fromUser);
                                    },
                                  );
                                },
                              );
                            },
                          ),

                          // Friends tab
                          StreamBuilder<List<UserModel>>(
                            stream: _friendsService.getFriendProfilesStream(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (snapshot.hasError) {
                                return Center(
                                  child: Text('Error: ${snapshot.error}'),
                                );
                              }

                              final friends = snapshot.data ?? [];

                              if (friends.isEmpty) {
                                return const Center(
                                  child: Text('No friends yet'),
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.all(16.0),
                                itemCount: friends.length,
                                itemBuilder: (context, index) {
                                  return _buildFriendTile(friends[index]);
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavBar(
        currentIndex: 1,
        onTap: (index) => _onNavBarTap(context, index),
      ),
    );
  }
}
