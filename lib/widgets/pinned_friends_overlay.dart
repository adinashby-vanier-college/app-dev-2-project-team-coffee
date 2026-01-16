import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../services/user_profile_service.dart';
import '../services/friends_service.dart';
import '../providers/auth_provider.dart';
import '../pages/friend_profile_page.dart';

class PinnedFriendsOverlay extends StatelessWidget {
  const PinnedFriendsOverlay({super.key});

  String _getInitials(UserModel user) {
    final displayName = user.displayName ?? user.name ?? user.email ?? '';
    if (displayName.isEmpty) {
      return '?';
    }
    final trimmed = displayName.trim();
    final parts = trimmed.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final userProfileService = UserProfileService();
    final friendsService = FriendsService();
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.user;

    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<String>>(
      stream: userProfileService.getPinnedFriendsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final pinnedFriendUids = snapshot.data!;
        // Limit to 3 pinned friends
        final limitedUids = pinnedFriendUids.take(3).toList();

        if (limitedUids.isEmpty) {
          return const SizedBox.shrink();
        }

        return FutureBuilder<List<UserModel>>(
          future: friendsService.getFriendProfiles(limitedUids),
          builder: (context, friendSnapshot) {
            if (!friendSnapshot.hasData || friendSnapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }

            final pinnedFriends = friendSnapshot.data!;
            
            // Match zoom button size: 44px × 44px
            // Border is 3px on each side, so inner radius = (44 - 6) / 2 = 19px
            const totalAvatarSize = 44.0; // Match zoom button size
            const borderWidth = 3.0;
            const avatarRadius = (totalAvatarSize - (borderWidth * 2)) / 2; // 19px
            const spacingBetweenAvatars = 8.0; // Match zoom button gap

            return Positioned(
              left: 16,
              bottom: 80, // Above the bottom navigation bar
              child: SizedBox(
                // Calculate total height: (avatar size * count) + (spacing * (count - 1))
                height: (totalAvatarSize * pinnedFriends.length) + 
                        (spacingBetweenAvatars * (pinnedFriends.length - 1)),
                width: totalAvatarSize,
                child: Stack(
                  clipBehavior: Clip.none, // Prevent clipping
                  children: pinnedFriends.asMap().entries.map((entry) {
                    final index = entry.key;
                    final friend = entry.value;
                    // Position from bottom: each avatar's bottom edge is spaced properly
                    // First avatar at bottom: 0, second at bottom: totalAvatarSize + spacing, etc.
                    final offset = index * (totalAvatarSize + spacingBetweenAvatars);

                    return Positioned(
                      bottom: offset,
                      left: 0,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FriendProfilePage(user: friend),
                            ),
                          );
                        },
                        child: Container(
                          width: totalAvatarSize,
                          height: totalAvatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: borderWidth,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: avatarRadius,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: friend.photoURL != null &&
                                    friend.photoURL!.isNotEmpty
                                ? CachedNetworkImageProvider(friend.photoURL!)
                                : null,
                            child: friend.photoURL == null ||
                                    friend.photoURL!.isEmpty
                                ? Text(
                                    _getInitials(friend),
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12, // Slightly smaller to fit better
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}