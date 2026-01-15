import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/moment_model.dart';
import '../services/moments_service.dart';
import '../services/friends_service.dart';
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
  late MomentModel _moment;
  List<UserModel> _invitedFriendProfiles = [];
  bool _isLoadingFriends = false;

  // Firebase Hosting URL for the shareable web form
  static const String _baseShareUrl = 'https://friendmap-5b654.web.app';

  @override
  void initState() {
    super.initState();
    _moment = widget.moment;
    _loadInvitedFriends();
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

  String get _shareUrl {
    if (_moment.shareCode == null) return '';
    return '$_baseShareUrl/moment/${_moment.shareCode}';
  }

  void _copyShareLink() async {
    if (_moment.shareCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No share link available')),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: _shareUrl));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard!')),
      );
    }
  }

  void _shareLink() async {
    if (_moment.shareCode == null) return;
    
    await Share.share(
      'Join me for ${_moment.title} at ${_moment.locationName}!\n\nRSVP here: $_shareUrl',
      subject: 'You\'re invited to ${_moment.title}',
    );
  }

  Future<void> _updateMyResponse(String response) async {
    try {
      await _momentsService.updateResponse(_moment.id, response);
      // Refresh moment data
      final updated = await _momentsService.getMomentById(_moment.id);
      if (updated != null && mounted) {
        setState(() => _moment = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You\'re ${response == 'going' ? 'going' : response}!')),
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
    final isSelected = _moment.responses.containsValue(response);
    
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
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'share':
                  _shareLink();
                  break;
                case 'copy':
                  _copyShareLink();
                  break;
                case 'delete':
                  _deleteMoment();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text('Share'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy),
                    SizedBox(width: 8),
                    Text('Copy Link'),
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

            // Share Link Section
            if (_moment.shareCode != null) ...[
              const Text(
                'Share Link',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _shareUrl,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: _copyShareLink,
                      tooltip: 'Copy link',
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, size: 20),
                      onPressed: _shareLink,
                      tooltip: 'Share',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Anyone with this link can RSVP to your moment!',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),
            ],

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
