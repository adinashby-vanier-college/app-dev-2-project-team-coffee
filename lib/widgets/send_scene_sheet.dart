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
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 448, maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 50,
              offset: const Offset(0, 25),
              spreadRadius: -12,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                ),
              ),
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
                  Material(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.close,
                          size: 20,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: const Text(
                'Select friends to share with',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
            ),

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
                        child: Text(
                          'Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  }

                  final friends = snapshot.data ?? [];
                  if (friends.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No friends yet',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Add friends to share locations with them',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      final isSelected = _selectedFriends.contains(friend.uid);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _handleFriendToggle(friend.uid),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFEFF6FF)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFFCBD5E1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: friend.photoURL?.isNotEmpty == true
                                        ? ClipOval(
                                            child: CachedNetworkImage(
                                              imageUrl: friend.photoURL!,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                              _getFriendInitials(friend),
                                              style: TextStyle(
                                                color: isSelected
                                                    ? Colors.white
                                                    : const Color(0xFF475569),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      friend.name?.isNotEmpty == true
                                          ? friend.name!
                                          : (friend.displayName?.isNotEmpty == true
                                              ? friend.displayName!
                                              : (friend.email ?? 'Unknown')),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF1E293B),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF2563EB)
                                            : const Color(0xFFCBD5E1),
                                        width: 2,
                                      ),
                                      color: isSelected
                                          ? const Color(0xFF2563EB)
                                          : Colors.transparent,
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF334155),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Material(
                      color: _selectedFriends.isEmpty
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: _selectedFriends.isEmpty
                            ? null
                            : _handleSendScene,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          child: Center(
                            child: Text(
                              _selectedFriends.isEmpty
                                  ? 'Send'
                                  : 'Send (${_selectedFriends.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
