import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/moment_model.dart';
import '../services/moments_service.dart';
import '../services/friends_service.dart';
import '../services/chat_service.dart';
import '../services/locations_service.dart';
import '../services/user_profile_service.dart';
import '../models/user_model.dart';

class MomentDetailPage extends StatefulWidget {
  final MomentModel moment;

  const MomentDetailPage({super.key, required this.moment});

  @override
  State<MomentDetailPage> createState() => _MomentDetailPageState();
}

class _MomentDetailPageState extends State<MomentDetailPage> {
  final MomentsService _momentsService = MomentsService();
  final FriendsService _friendsService = FriendsService();
  final ChatService _chatService = ChatService();
  final LocationsService _locationsService = LocationsService();
  final UserProfileService _userProfileService = UserProfileService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  late MomentModel _moment;
  List<UserModel> _invitedFriendProfiles = [];
  bool _isLoadingFriends = false;
  UserModel? _creator;
  bool _isLoadingCreator = false;
  
  // Edit mode state
  bool _isEditMode = false;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 12, minute: 0);
  bool _isSaving = false;
  List<Map<String, dynamic>> _availableLocations = [];
  bool _isLoadingLocations = false;

  bool get _isCreator {
    final currentUser = _auth.currentUser;
    return currentUser != null && currentUser.uid == _moment.createdBy;
  }

  String? get _currentUserResponse {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;
    return _moment.responses[currentUser.uid];
  }

  @override
  void initState() {
    super.initState();
    _moment = widget.moment;
    _titleController.text = _moment.title;
    _descriptionController.text = _moment.description ?? '';
    _selectedDate = _moment.dateTime;
    _selectedTime = TimeOfDay.fromDateTime(_moment.dateTime);
    _loadInvitedFriends();
    _loadCreator();
  }

  Future<void> _loadCreator() async {
    setState(() => _isLoadingCreator = true);
    try {
      final creator = await _userProfileService.getUserByUid(_moment.createdBy);
      if (mounted) {
        setState(() {
          _creator = creator;
          _isLoadingCreator = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCreator = false);
        debugPrint('Error loading creator: $e');
      }
    }
  }

  String _getCreatorDisplayName() {
    if (_creator == null) return '';
    return _creator!.name ?? 
           _creator!.displayName ?? 
           _creator!.email ?? 
           'Unknown';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadInvitedFriends() async {
    if (_moment.invitedFriends.isEmpty) return;
    
    setState(() => _isLoadingFriends = true);
    try {
      final profiles = await _friendsService.getFriendProfiles(_moment.invitedFriends);
      setState(() {
        _invitedFriendProfiles = profiles;
        _isLoadingFriends = false;
      });
    } catch (e) {
      setState(() => _isLoadingFriends = false);
      debugPrint('Error loading friend profiles: $e');
    }
  }

  Future<void> _sendToFriend() async {
    // Get list of friends
    final friends = await _friendsService.getFriendProfiles(
      await _friendsService.getFriendsListOnce(),
    );

    if (friends.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need to add friends first!')),
        );
      }
      return;
    }

    // Show friend picker dialog
    final selectedFriends = await showDialog<List<UserModel>>(
      context: context,
      builder: (context) => _FriendPickerDialog(friends: friends),
    );

    if (selectedFriends == null || selectedFriends.isEmpty || !mounted) return;

    try {
      int successCount = 0;
      int failCount = 0;

      // Collect friend IDs for batch invite
      final friendIds = selectedFriends.map((f) => f.uid).toList();
      
      debugPrint('MomentDetailPage: Adding ${friendIds.length} friends to invitedFriends for moment ${_moment.id}');
      
      // Add all selected friends to invitedFriends array
      try {
        await _momentsService.inviteFriends(_moment.id, friendIds);
        debugPrint('MomentDetailPage: Successfully added friends to invitedFriends');
      } catch (e) {
        debugPrint('MomentDetailPage: Error adding friends to invitedFriends: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error inviting friends: $e')),
          );
        }
      }

      for (final friend in selectedFriends) {
        try {
          // Get or create conversation with the selected friend
          final conversationId = await _chatService.getOrCreateConversation(
            friend.uid,
          );

          // Send moment card
          await _chatService.sendMessage(
            conversationId,
            momentId: _moment.id,
          );
          successCount++;
        } catch (e) {
          failCount++;
          debugPrint('Error sending to ${friend.uid}: $e');
        }
      }

      if (mounted) {
        if (successCount > 0) {
          if (failCount == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  successCount == 1
                      ? 'Moment sent to 1 friend!'
                      : 'Moment sent to $successCount friends!',
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Sent to $successCount friend${successCount > 1 ? 's' : ''}, $failCount failed',
                ),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send moment to any friends'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending moment: $e')),
        );
      }
    }
  }

  Future<void> _updateMyResponse(String response) async {
    try {
      final currentResponse = _currentUserResponse;
      if (currentResponse == response) {
        await _momentsService.clearResponse(_moment.id);
      } else {
        await _momentsService.updateResponse(_moment.id, response);
      }
      // Refresh moment data
      final updated = await _momentsService.getMomentById(_moment.id);
      if (updated != null && mounted) {
        setState(() => _moment = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentResponse == response
                  ? 'Response cleared.'
                  : 'You\'re ${response == 'going' ? 'going' : response}!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating response: $e')),
        );
      }
    }
  }

  Future<void> _toggleEditMode() async {
    if (_isEditMode) {
      // Cancel edit mode - reset to original values
      setState(() {
        _isEditMode = false;
        _titleController.text = _moment.title;
        _descriptionController.text = _moment.description ?? '';
        _selectedDate = _moment.dateTime;
        _selectedTime = TimeOfDay.fromDateTime(_moment.dateTime);
      });
    } else {
      // Enter edit mode
      setState(() {
        _isEditMode = true;
      });
      await _loadLocations();
    }
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoadingLocations = true);
    try {
      final locations = await _locationsService.getAllLocations();
      setState(() {
        _availableLocations = locations;
        _isLoadingLocations = false;
      });
    } catch (e) {
      setState(() => _isLoadingLocations = false);
      debugPrint('Error loading locations: $e');
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  DateTime get _combinedDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _saveChanges() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _momentsService.updateMoment(
        _moment.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        dateTime: _combinedDateTime,
      );

      // Refresh moment data
      final updated = await _momentsService.getMomentById(_moment.id);
      if (updated != null && mounted) {
        setState(() {
          _moment = updated;
          _isEditMode = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Moment updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating moment: $e')),
        );
      }
    }
  }

  Future<void> _deleteMoment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Moment?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _momentsService.deleteMoment(_moment.id);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Moment deleted')),
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
  }

  Widget _buildResponseButton(String response, String label, IconData icon, Color color) {
    final isSelected = _currentUserResponse == response;
    
    return Expanded(
      child: InkWell(
        onTap: () => _updateMyResponse(response),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.grey.shade600,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(_moment.dateTime);
    final timeStr = DateFormat('h:mm a').format(_moment.dateTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moment Details'),
        centerTitle: true,
        actions: [
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _toggleEditMode,
              tooltip: 'Cancel',
            )
          else if (_isCreator)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _toggleEditMode();
                    break;
                  case 'delete':
                    _deleteMoment();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isEditMode) ...[
              // Edit Mode UI
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Event Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.title),
                ),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              // Date & Time in Edit Mode
              const Text(
                'Date & Time',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('MMM d, yyyy').format(_selectedDate),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _selectTime,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _selectedTime.format(context),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              // View Mode UI
              // Title & Status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _moment.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _moment.isUpcoming 
                          ? Colors.green.shade50 
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _moment.isUpcoming ? 'Upcoming' : 'Past',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _moment.isUpcoming 
                            ? Colors.green.shade700 
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Creator label
              if (_isLoadingCreator)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Created by...',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else if (_creator != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Created by ${_getCreatorDisplayName()}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Description
              if (_moment.description != null && _moment.description!.isNotEmpty) ...[
                Text(
                  _moment.description!,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ],

            if (!_isEditMode) ...[
              // Date & Time Card
              Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.event, color: Colors.blue.shade700),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Location Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.place, color: Colors.green.shade700),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _moment.locationName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_moment.locationAddress.isNotEmpty)
                          Text(
                            _moment.locationAddress,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

              // Send to Friend Section
            const Text(
              'Send to Friend',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _sendToFriend,
              icon: const Icon(Icons.send),
              label: const Text('Send Moment to Friend'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: const Color(0xFF58ae45),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share this moment with a friend in chat!',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),

            // RSVP Section
            const Text(
              'Your Response',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildResponseButton('going', 'Going', Icons.check_circle, Colors.green),
                const SizedBox(width: 8),
                _buildResponseButton('maybe', 'Maybe', Icons.help_outline, Colors.orange),
                const SizedBox(width: 8),
                _buildResponseButton('not_going', 'Can\'t Go', Icons.cancel, Colors.red),
              ],
            ),
            const SizedBox(height: 24),

            // Responses Summary
            const Text(
              'Responses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildResponseStat('Going', _moment.goingCount, Colors.green),
                const SizedBox(width: 16),
                _buildResponseStat('Maybe', _moment.maybeCount, Colors.orange),
              ],
            ),
            
            // Guest Responses
            if (_moment.guestResponses.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Guest RSVPs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ..._moment.guestResponses.map((guest) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.shade100,
                  child: Text(
                    (guest['name'] as String? ?? '?')[0].toUpperCase(),
                    style: TextStyle(color: Colors.purple.shade700),
                  ),
                ),
                title: Text(guest['name'] as String? ?? 'Guest'),
                subtitle: Text(guest['response'] as String? ?? ''),
                trailing: guest['note'] != null 
                    ? IconButton(
                        icon: const Icon(Icons.note),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('${guest['name']}\'s Note'),
                              content: Text(guest['note'] as String),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : null,
              )),
            ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResponseStat(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendPickerDialog extends StatefulWidget {
  final List<UserModel> friends;

  const _FriendPickerDialog({required this.friends});

  @override
  State<_FriendPickerDialog> createState() => _FriendPickerDialogState();
}

class _FriendPickerDialogState extends State<_FriendPickerDialog> {
  final Set<String> _selectedFriendIds = {};

  String _getDisplayName(UserModel friend) {
    return friend.name ?? friend.displayName ?? friend.email ?? 'Unknown';
  }

  String _getInitials(UserModel friend) {
    final name = friend.name ?? friend.displayName;
    if (name != null && name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    final email = friend.email;
    if (email != null && email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Select Friends',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedFriendIds.isNotEmpty)
                    Text(
                      '${_selectedFriendIds.length} selected',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: widget.friends.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No friends available'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.friends.length,
                      itemBuilder: (context, index) {
                        final friend = widget.friends[index];
                        final isSelected = _selectedFriendIds.contains(friend.uid);
                        final displayName = _getDisplayName(friend);
                        final initials = _getInitials(friend);

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedFriendIds.add(friend.uid);
                              } else {
                                _selectedFriendIds.remove(friend.uid);
                              }
                            });
                          },
                          secondary: CircleAvatar(
                            backgroundImage: friend.photoURL != null
                                ? NetworkImage(friend.photoURL!)
                                : null,
                            child: friend.photoURL == null
                                ? Text(initials)
                                : null,
                          ),
                          title: Text(displayName),
                          subtitle: friend.email != null
                              ? Text(friend.email!)
                              : null,
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectedFriendIds.isEmpty
                        ? null
                        : () {
                            final selectedFriends = widget.friends
                                .where((f) => _selectedFriendIds.contains(f.uid))
                                .toList();
                            Navigator.pop(context, selectedFriends);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF58ae45),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Send'),
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
