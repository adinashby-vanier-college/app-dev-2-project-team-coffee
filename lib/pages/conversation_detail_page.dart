import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../services/chat_service.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/location_details.dart';
import '../services/locations_service.dart';
import '../widgets/location_preview_card.dart';
import '../widgets/location_detail_sheet.dart';
import '../widgets/moment_preview_card.dart';
import '../services/moments_service.dart';
import '../models/moment_model.dart';
import 'moment_detail_page.dart';

class ConversationDetailPage extends StatefulWidget {
  final String conversationId;
  final UserModel otherUser;

  const ConversationDetailPage({
    super.key,
    required this.conversationId,
    required this.otherUser,
  });

  @override
  State<ConversationDetailPage> createState() => _ConversationDetailPageState();
}

class _ConversationDetailPageState extends State<ConversationDetailPage> {
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Mark messages as read when opening conversation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatService.markMessagesAsRead(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('MMM d, HH:mm').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.user?.uid ?? '';
    var displayName = widget.otherUser.name;
    if (displayName == null || displayName.isEmpty) {
      displayName = widget.otherUser.displayName;
    }
    if (displayName == null || displayName.isEmpty) {
      displayName = widget.otherUser.email;
    }
    if (displayName == null || displayName.isEmpty) {
      displayName = 'Unknown User';
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.otherUser.photoURL != null
                  ? CachedNetworkImageProvider(widget.otherUser.photoURL!)
                  : null,
              child: widget.otherUser.photoURL == null
                  ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?')
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _chatService.getMessages(widget.conversationId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'No shared locations yet.\nSend a scene from the map to start sharing!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildMessageBubble(context, message, isMe),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Input area removed as per requirements ("we are not sending any words")
          // Optional: Add a helper text explaining how to send
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            width: double.infinity,
            child: Text(
              'Go to a location on the map to share it',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, Message message, bool isMe) {
    if (message.locationId != null) {
      return SizedBox(
        width: MediaQuery.of(context).size.width * 0.75,
        child: _LocationMessageBubble(
          locationId: message.locationId!,
          isMe: isMe,
          timestamp: message.timestamp,
        ),
      );
    }
    
    if (message.momentId != null) {
      return SizedBox(
        width: MediaQuery.of(context).size.width * 0.75,
        child: _MomentMessageBubble(
          momentId: message.momentId!,
          isMe: isMe,
          timestamp: message.timestamp,
        ),
      );
    }
    
    // Fallback for legacy text messages (if any)
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: isMe
            ? Theme.of(context).primaryColor
            : Colors.grey[300],
        borderRadius: BorderRadius.circular(18),
      ),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.text,
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatMessageTime(message.timestamp),
            style: TextStyle(
              fontSize: 10,
              color: isMe
                  ? Colors.white70
                  : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationMessageBubble extends StatefulWidget {
  final String locationId;
  final bool isMe;
  final DateTime timestamp;

  const _LocationMessageBubble({
    required this.locationId,
    required this.isMe,
    required this.timestamp,
  });

  @override
  State<_LocationMessageBubble> createState() => _LocationMessageBubbleState();
}

class _LocationMessageBubbleState extends State<_LocationMessageBubble> {
  final LocationsService _locationsService = LocationsService();
  Map<String, dynamic>? _locationData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final data = await _locationsService.getLocationById(widget.locationId);
      if (mounted) {
        setState(() {
          _locationData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  LocationDetails? _convertToLocationDetails(Map<String, dynamic>? data) {
    if (data == null) return null;
    // Basic conversion sufficient for detail sheet
    return LocationDetails(
      id: data['id'] ?? widget.locationId,
      name: data['name'] ?? 'Unknown Location',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      reviews: data['reviews'] ?? '0',
      price: data['price'],
      category: data['category'] ?? 'Place',
      address: data['address'] ?? '',
      openStatus: data['openStatus'],
      closeTime: data['closeTime'],
      phone: data['phone'],
      website: data['website'],
      description: data['description'] ?? '',
      hours: [], // Not critical for bubble, will be re-fetched or handled if needed
    );
  }

  void _openLocation(BuildContext context) {
    if (_locationData == null) return;
    
    final location = _convertToLocationDetails(_locationData);
    if (location != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => LocationDetailSheet(location: location),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        LocationPreviewCard(
          locationId: widget.locationId,
          name: _locationData?['name'],
          address: _locationData?['address'],
          onTap: () => _openLocation(context),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('HH:mm').format(widget.timestamp),
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _MomentMessageBubble extends StatefulWidget {
  final String momentId;
  final bool isMe;
  final DateTime timestamp;

  const _MomentMessageBubble({
    required this.momentId,
    required this.isMe,
    required this.timestamp,
  });

  @override
  State<_MomentMessageBubble> createState() => _MomentMessageBubbleState();
}

class _MomentMessageBubbleState extends State<_MomentMessageBubble> {
  final MomentsService _momentsService = MomentsService();
  MomentModel? _moment;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMoment();
  }

  Future<void> _loadMoment() async {
    try {
      final moment = await _momentsService.getMomentById(widget.momentId);
      if (mounted) {
        setState(() {
          _moment = moment;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openMoment(BuildContext context) {
    if (_moment == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MomentDetailPage(moment: _moment!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (_isLoading)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          MomentPreviewCard(
            momentId: widget.momentId,
            moment: _moment,
            onTap: () => _openMoment(context),
          ),
        const SizedBox(height: 4),
        Text(
          DateFormat('HH:mm').format(widget.timestamp),
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
