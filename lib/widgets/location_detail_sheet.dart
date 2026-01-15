import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/location_details.dart';
import '../providers/saved_locations_provider.dart';
import '../services/friends_service.dart';
import '../models/user_model.dart';

class LocationDetailSheet extends StatefulWidget {
  final LocationDetails location;

  const LocationDetailSheet({
    super.key,
    required this.location,
  });

  @override
  State<LocationDetailSheet> createState() => _LocationDetailSheetState();
}

class _LocationDetailSheetState extends State<LocationDetailSheet> {
  bool _isHoursExpanded = false;
  bool _isSendSceneModalOpen = false;
  final Set<String> _selectedFriends = {};
  final FriendsService _friendsService = FriendsService();

  Future<void> _toggleSave() async {
    final provider = context.read<SavedLocationsProvider>();
    try {
      if (provider.isSaved(widget.location.id)) {
        await provider.unsaveLocation(widget.location.id);
      } else {
        await provider.saveLocation(widget.location.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating saved state: $e')),
        );
      }
    }
  }

  Future<void> _openAddress() async {
    final address = widget.location.address;
    if (address.isEmpty) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }


  Widget _buildSaveButton(LocationDetails loc) {
    final provider = context.watch<SavedLocationsProvider>();
    final isSaved = provider.isSaved(loc.id);
    final borderColor =
        isSaved ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0);
    final bgColor =
        isSaved ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC);
    final textColor =
        isSaved ? const Color(0xFF15803D) : const Color(0xFF475569);

    return InkWell(
      onTap: _toggleSave,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
              size: 20,
              color: borderColor,
            ),
            const SizedBox(height: 4),
            Text(
              'Save',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendSceneButton() {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFriends.clear();
          _isSendSceneModalOpen = true;
        });
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            Icon(
              Icons.share,
              size: 20,
              color: Color(0xFF475569),
            ),
            SizedBox(height: 4),
            Text(
              'Send Scene™',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
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

  void _handleSendScene() {
    // Just close the modal - no actual sending for demo (matching map modal behavior)
    setState(() {
      _isSendSceneModalOpen = false;
      _selectedFriends.clear();
    });
  }

  void _handleCancelSendScene() {
    setState(() {
      _isSendSceneModalOpen = false;
      _selectedFriends.clear();
    });
  }

  String _getFriendInitials(UserModel friend) {
    final name = friend.name ?? friend.displayName ?? '';
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.location;

    return Stack(
      children: [
        SafeArea(
          top: true,
          bottom: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.7,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    loc.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  loc.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(
                                    5,
                                    (i) => Icon(
                                      Icons.star,
                                      size: 14,
                                      color: i < loc.rating.round()
                                          ? Colors.amber
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                                Text(
                                  '(${loc.reviews} reviews)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  '• ${loc.category}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (loc.price != null &&
                                    loc.price!.isNotEmpty)
                                  Text(
                                    loc.price!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              loc.description,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: _buildSaveButton(loc)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildSendSceneButton()),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading:
                                  const Icon(Icons.place, color: Colors.blue),
                              title: Text(
                                loc.address,
                                style: const TextStyle(fontSize: 14),
                              ),
                              onTap: _openAddress,
                            ),
                            if (loc.phone != null && loc.phone!.isNotEmpty)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading:
                                    const Icon(Icons.phone, color: Colors.blue),
                                title: Text(
                                  loc.phone!,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                onTap: () async {
                                  final uri =
                                      Uri(scheme: 'tel', path: loc.phone);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri);
                                  }
                                },
                              ),
                            if (loc.website != null && loc.website!.isNotEmpty)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.language,
                                    color: Colors.blue),
                                title: Text(
                                  loc.website!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                onTap: () async {
                                  final uri = Uri.parse(loc.website!);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri,
                                        mode: LaunchMode.externalApplication);
                                  }
                                },
                              ),
                            if (loc.hours.isNotEmpty) ...[
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.access_time,
                                    color: Colors.blue),
                                title: Row(
                                  children: [
                                    Text(
                                      loc.openStatus ?? 'Hours',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: (loc.openStatus ?? '')
                                                .toLowerCase()
                                                .contains('open')
                                            ? Colors.green
                                            : Colors.orange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (loc.closeTime != null &&
                                        loc.closeTime!.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '· Closes ${loc.closeTime}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    _isHoursExpanded
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isHoursExpanded = !_isHoursExpanded;
                                    });
                                  },
                                ),
                              ),
                              if (_isHoursExpanded)
                                Padding(
                                  padding: const EdgeInsets.only(left: 40),
                                  child: Column(
                                    children: loc.hours
                                        .map(
                                          (h) => Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                h.day,
                                                style: const TextStyle(
                                                    fontSize: 13),
                                              ),
                                              Text(
                                                h.time,
                                                style: const TextStyle(
                                                    fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                            ],
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Send Scene Modal
        if (_isSendSceneModalOpen)
          GestureDetector(
            onTap: _handleCancelSendScene,
            child: Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: GestureDetector(
                  onTap: () {}, // Prevent tap from closing when clicking modal
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    constraints: const BoxConstraints(maxHeight: 600),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.all(24),
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
                                onPressed: _handleCancelSendScene,
                                icon: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 20,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Select friends to share with',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                        // Friends List
                        Flexible(
                          child: StreamBuilder<List<UserModel>>(
                            stream: _friendsService.getFriendProfilesStream(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              if (snapshot.hasError) {
                                return Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Center(
                                    child: Text(
                                      'Error loading friends: ${snapshot.error}',
                                      style: TextStyle(color: Colors.red.shade700),
                                    ),
                                  ),
                                );
                              }

                              final friends = snapshot.data ?? [];

                              if (friends.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(
                                    child: Text(
                                      'No friends yet',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: friends.length,
                                itemBuilder: (context, index) {
                                  final friend = friends[index];
                                  final isSelected =
                                      _selectedFriends.contains(friend.uid);

                                  return InkWell(
                                    onTap: () => _handleFriendToggle(friend.uid),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.blue.shade50
                                            : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.blue.shade500
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Avatar
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Colors.blue.shade500
                                                  : Colors.grey.shade300,
                                              shape: BoxShape.circle,
                                            ),
                                            child: friend.photoURL != null &&
                                                    friend.photoURL!.isNotEmpty
                                                ? ClipOval(
                                                    child: CachedNetworkImage(
                                                      imageUrl: friend.photoURL!,
                                                      fit: BoxFit.cover,
                                                      errorWidget: (context, url,
                                                              error) =>
                                                          Center(
                                                        child: Text(
                                                          _getFriendInitials(
                                                              friend),
                                                          style: TextStyle(
                                                            color: isSelected
                                                                ? Colors.white
                                                                : Colors.grey
                                                                    .shade600,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : Center(
                                                    child: Text(
                                                      _getFriendInitials(friend),
                                                      style: TextStyle(
                                                        color: isSelected
                                                            ? Colors.white
                                                            : Colors.grey
                                                                .shade600,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Name
                                          Expanded(
                                            child: Text(
                                              friend.name ??
                                                  friend.displayName ??
                                                  'Unknown',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                          ),
                                          // Checkbox
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Colors.blue.shade500
                                                  : Colors.transparent,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSelected
                                                    ? Colors.blue.shade500
                                                    : Colors.grey.shade300,
                                                width: 2,
                                              ),
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
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Footer Buttons
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _handleCancelSendScene,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    side: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _selectedFriends.isEmpty
                                      ? null
                                      : _handleSendScene,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    backgroundColor: Colors.blue.shade600,
                                    disabledBackgroundColor: Colors.grey.shade300,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    _selectedFriends.isEmpty
                                        ? 'Send'
                                        : 'Send (${_selectedFriends.length})',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: _selectedFriends.isEmpty
                                          ? Colors.grey.shade600
                                          : Colors.white,
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
                ),
              ),
            ),
          ),
      ],
    );
  }
}

