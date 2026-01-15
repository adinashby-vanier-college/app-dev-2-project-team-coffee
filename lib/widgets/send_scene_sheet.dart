import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/friends_service.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';

class SendSceneSheet extends StatefulWidget {
  final String locationId;

  const SendSceneSheet({
    super.key,
    required this.locationId,
  });

  @override
  State<SendSceneSheet> createState() => _SendSceneSheetState();
}

class _SendSceneSheetState extends State<SendSceneSheet> {
  final Set<String> _selectedFriends = {};
  final FriendsService _friendsService = FriendsService();
  Future<List<UserModel>>? _friendsFuture;

  @override
  void initState() {
    super.initState();
    _friendsFuture = _loadFriendsOnce();
  }

  Future<List<UserModel>> _loadFriendsOnce() async {
    debugPrint('LOG-SHEET: _loadFriendsOnce started');
    try {
      final friendUids = await _friendsService.getFriendsListOnce();
      debugPrint('LOG-SHEET: Got ${friendUids.length} friend UIDs');
      
      if (friendUids.isEmpty) {
        debugPrint('LOG-SHEET: No friends found');
        return [];
      }
      
      final profiles = await _friendsService.getFriendProfiles(friendUids);
      debugPrint('LOG-SHEET: Loaded ${profiles.length} profiles');
      return profiles;
    } catch (e, stackTrace) {
      debugPrint('LOG-SHEET: ERROR in _loadFriendsOnce: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  void _handleFriendToggle(String friendId) {
    setState(() {
      if (_selectedFriends.contains(friendId)) {
        _selectedFriends.remove(friendId);
      } else {
        _selectedFriends.add(friendId);
      }
    });
  }

  Future<void> _handleSendScene() async {
    final selectedFriends = List<String>.from(_selectedFriends);
    if (selectedFriends.isEmpty) return;

    debugPrint('LOG-SHEET: Sending scene to ${selectedFriends.length} friends');
    final chatService = ChatService();

    // Close before processing to feel responsive
    Navigator.of(context).pop();

    try {
      for (final friendId in selectedFriends) {
        final conversationId = await chatService.getOrCreateConversation(friendId);
        await chatService.sendMessage(
          conversationId,
          locationId: widget.locationId,
        );
      }
      debugPrint('LOG-SHEET: All messages sent successfully');
    } catch (e) {
      debugPrint('LOG-SHEET: ERROR sending scene: $e');
    }
  }

  String _getFriendInitials(UserModel friend) {
    String label = (friend.name?.isNotEmpty == true)
        ? friend.name!
        : (friend.displayName?.isNotEmpty == true)
            ? friend.displayName!
            : friend.email?.split('@').first ?? '?';
    
    label = label.trim();
    if (label.isEmpty) return '?';
    final parts = label.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return label[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Send Scene™',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  'Select friends to share with',
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
              ),
              
              const Divider(height: 32),

              // Content
              Flexible(
                child: FutureBuilder<List<UserModel>>(
                  future: _friendsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Error: ${snapshot.error}', 
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red)),
                        ),
                      );
                    }
                    
                    final friends = snapshot.data ?? [];
                    if (friends.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Text('No friends yet', 
                            style: TextStyle(color: Color(0xFF94A3B8))),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        final isSelected = _selectedFriends.contains(friend.uid);
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () => _handleFriendToggle(friend.uid),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue.withOpacity(0.05) : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? Colors.blue : Colors.grey.shade200,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: isSelected ? Colors.blue : Colors.grey.shade100,
                                    backgroundImage: friend.photoURL?.isNotEmpty == true 
                                        ? CachedNetworkImageProvider(friend.photoURL!) 
                                        : null,
                                    child: friend.photoURL?.isNotEmpty == true 
                                        ? null 
                                        : Text(_getFriendInitials(friend), 
                                            style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      friend.name?.isNotEmpty == true
                                          ? friend.name!
                                          : (friend.displayName?.isNotEmpty == true
                                              ? friend.displayName!
                                              : (friend.email ?? 'Unknown')),
                                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                    ),
                                  ),
                                  Icon(
                                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                                    color: isSelected ? Colors.blue : Colors.grey.shade300,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const Divider(height: 32),

              // Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _selectedFriends.isEmpty ? null : _handleSendScene,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('Send (${_selectedFriends.length})'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
