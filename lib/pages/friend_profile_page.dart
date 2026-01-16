import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../services/saved_locations_service.dart';
import '../services/locations_service.dart';
import '../models/location_details.dart';
import '../widgets/location_preview_card.dart';
import '../widgets/location_detail_sheet.dart';
import '../services/friends_service.dart';
import '../services/user_profile_service.dart';
import '../services/chat_service.dart';
import 'conversation_detail_page.dart';

class FriendProfilePage extends StatefulWidget {
  final UserModel user;

  const FriendProfilePage({super.key, required this.user});

  @override
  State<FriendProfilePage> createState() => _FriendProfilePageState();
}

class _FriendProfilePageState extends State<FriendProfilePage> {
  final SavedLocationsService _savedLocationsService = SavedLocationsService();
  final LocationsService _locationsService = LocationsService();
  final FriendsService _friendsService = FriendsService();
  final UserProfileService _userProfileService = UserProfileService();
  final ChatService _chatService = ChatService();
  bool _isPinned = false;
  bool _isLoadingPinStatus = true;
  Map<String, Map<String, dynamic>?> _locationDetailsCache = {};
  bool _isLoadingLocations = false;

  Future<void> _openLocation(String locationId) async {
    // Show loading indicator or simple visual feedback could be nice, 
    // but LocationDetailSheet needs the full object.
    
    try {
      final locationData = await _locationsService.getLocationById(locationId);
      if (locationData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location details not found')),
          );
        }
        return;
      }

      final location = _convertMapToLocationDetails(locationData);

      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => LocationDetailSheet(
            location: location,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading location: $e')),
        );
      }
    }
  }

  LocationDetails _convertMapToLocationDetails(Map<String, dynamic> data) {
    // Convert hours array from Firebase format to DayHours objects
    List<DayHours> hours = [];
    if (data['hours'] != null && data['hours'] is List) {
      hours = (data['hours'] as List).map((hour) {
        return DayHours(
          day: hour['day'] as String? ?? '',
          time: hour['time'] as String? ?? '',
        );
      }).toList();
    }

    return LocationDetails(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? 'Unknown Location',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      reviews: data['reviews'] as String? ?? '0',
      price: data['price'] as String?,
      category: data['category'] as String? ?? 'Location',
      address: data['address'] as String? ?? '',
      openStatus: data['openStatus'] as String?,
      closeTime: data['closeTime'] as String?,
      phone: data['phone'] as String?,
      website: data['website'] as String?,
      description: data['description'] as String? ?? '',
      hours: hours,
    );
  }

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  Future<void> _checkPinStatus() async {
    try {
      final pinnedFriends = await _userProfileService.getPinnedFriends();
      setState(() {
        _isPinned = pinnedFriends.contains(widget.user.uid);
        _isLoadingPinStatus = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPinStatus = false;
      });
    }
  }

  Future<void> _loadLocationDetails(List<String> locationIds) async {
    if (locationIds.isEmpty) {
      setState(() {
        _locationDetailsCache = {};
        _isLoadingLocations = false;
      });
      return;
    }

    setState(() => _isLoadingLocations = true);

    final Map<String, Map<String, dynamic>?> newCache = {};
    
    // Fetch location details for all IDs in parallel
    final futures = locationIds.map((id) async {
      try {
        final details = await _locationsService.getLocationById(id);
        return MapEntry(id, details);
      } catch (e) {
        debugPrint('Error loading location $id: $e');
        return MapEntry(id, null);
      }
    });

    final results = await Future.wait(futures);
    for (final entry in results) {
      newCache[entry.key] = entry.value;
    }

    if (mounted) {
      setState(() {
        _locationDetailsCache = newCache;
        _isLoadingLocations = false;
      });
    }
  }

  Future<void> _togglePinFriend() async {
    try {
      if (_isPinned) {
        await _userProfileService.unpinFriend(widget.user.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.user.name ?? widget.user.email ?? 'Friend'} unpinned from home map')),
          );
        }
      } else {
        await _userProfileService.pinFriend(widget.user.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.user.name ?? widget.user.email ?? 'Friend'} pinned to home map')),
          );
        }
      }
      setState(() {
        _isPinned = !_isPinned;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _startChat() async {
    try {
      final conversationId = await _chatService.getOrCreateConversation(widget.user.uid);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConversationDetailPage(
              conversationId: conversationId,
              otherUser: widget.user,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting chat: $e')),
        );
      }
    }
  }

  Future<void> _unfriend() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unfriend'),
        content: Text('Are you sure you want to remove ${widget.user.name ?? widget.user.email ?? 'this user'} from your friends?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unfriend'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _friendsService.unfriend(widget.user.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.user.name ?? widget.user.email ?? 'User'} has been removed from your friends')),
        );
        // Navigate back after unfriending
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user.displayName ?? 'Friend Profile'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'pin') {
                _togglePinFriend();
              } else if (value == 'unfriend') {
                _unfriend();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'pin',
                enabled: !_isLoadingPinStatus,
                child: Row(
                  children: [
                    Icon(
                      _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: _isPinned ? Colors.orange : null,
                    ),
                    const SizedBox(width: 8),
                    Text(_isPinned ? 'Unpin from home map' : 'Pin friend to home map'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'unfriend',
                child: Row(
                  children: [
                    Icon(Icons.person_remove, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Unfriend', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Profile Picture
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: widget.user.photoURL != null &&
                        widget.user.photoURL!.isNotEmpty
                    ? CachedNetworkImageProvider(widget.user.photoURL!)
                    : null,
                child:
                    widget.user.photoURL == null || widget.user.photoURL!.isEmpty
                        ? Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.grey.shade600,
                          )
                        : null,
              ),
              const SizedBox(height: 16),
              // Name
              Text(
                widget.user.displayName ?? 'No Name',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Email
              Text(
                widget.user.email ?? '',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              // Chat Button
              ElevatedButton.icon(
                onPressed: _startChat,
                icon: const Icon(Icons.chat),
                label: const Text('Open Chat'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 40),
              // Saved Locations Section
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Saved locations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              
              StreamBuilder<List<String>>(
                stream: _savedLocationsService.getSavedLocationsStreamForUser(widget.user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final savedLocationIds = snapshot.data ?? [];

                  if (savedLocationIds.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'No saved locations yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  // Load location details when the list changes
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final currentIds = savedLocationIds.toList()..sort();
                    final cachedIds = _locationDetailsCache.keys.toList()..sort();
                    if (currentIds.join(',') != cachedIds.join(',')) {
                      _loadLocationDetails(savedLocationIds);
                    }
                  });

                  if (_isLoadingLocations) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: savedLocationIds.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final locationId = savedLocationIds[index];
                      final locationData = _locationDetailsCache[locationId];
                      final locationName = locationData?['name'] as String?;
                      final locationDescription = locationData?['description'] as String?;
                      
                      return LocationPreviewCard(
                        locationId: locationId,
                        name: locationName,
                        description: locationDescription,
                        onTap: () => _openLocation(locationId),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
