import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'chat_service.dart';
import 'moments_service.dart';
import 'notification_service.dart';
import 'user_profile_service.dart';

/// Manages real-time notifications for messages, moments, and scenes
/// Listens to Firebase changes even when offline (via Firestore persistence)
class NotificationManager extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  final MomentsService _momentsService = MomentsService();
  final NotificationService _notificationService = NotificationService();
  final UserProfileService _userProfileService = UserProfileService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot>? _conversationsSubscription;
  StreamSubscription<QuerySnapshot>? _momentsSubscription;
  final Map<String, StreamSubscription> _messageSubscriptions = {};
  final Set<String> _knownMessageIds = {};
  final Set<String> _knownMomentInviteIds = {};
  bool _isInitialized = false;

  /// Initialize listeners for notifications
  void initialize() {
    if (_isInitialized) return;
    
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('NotificationManager: No user, waiting for auth state...');
      _auth.authStateChanges().listen((user) {
        if (user != null && !_isInitialized) {
          _startListening();
        } else if (user == null) {
          _stopListening();
        }
      });
      return;
    }

    _startListening();
  }

  void _startListening() {
    if (_isInitialized) return;
    _isInitialized = true;

    debugPrint('NotificationManager: Starting listeners...');
    _listenToMessages();
    _listenToMoments();
  }

  void _stopListening() {
    _conversationsSubscription?.cancel();
    _momentsSubscription?.cancel();
    _conversationsSubscription = null;
    _momentsSubscription = null;
    
    // Cancel all message subscriptions
    for (final subscription in _messageSubscriptions.values) {
      subscription.cancel();
    }
    _messageSubscriptions.clear();
    
    _knownMessageIds.clear();
    _knownMomentInviteIds.clear();
    _isInitialized = false;
  }

  /// Listen to new messages in all user's conversations
  void _listenToMessages() {
    final user = _auth.currentUser;
    if (user == null) return;

    debugPrint('NotificationManager: Setting up messages listener...');

    // First, get all conversations
    _conversationsSubscription = _firestore
        .collection('conversations')
        .where('participants', arrayContains: user.uid)
        .snapshots()
        .listen((conversationsSnapshot) async {
      final conversationIds = conversationsSnapshot.docs.map((doc) => doc.id).toSet();
      debugPrint('NotificationManager: Found ${conversationIds.length} conversations');

      // Cancel subscriptions for conversations that no longer exist
      final currentSubscriptionIds = _messageSubscriptions.keys.toSet();
      for (final oldId in currentSubscriptionIds) {
        if (!conversationIds.contains(oldId)) {
          _messageSubscriptions[oldId]?.cancel();
          _messageSubscriptions.remove(oldId);
          debugPrint('NotificationManager: Removed listener for conversation $oldId');
        }
      }

      // Listen to messages in each conversation (only if not already listening)
      for (final conversationId in conversationIds) {
        if (_messageSubscriptions.containsKey(conversationId)) {
          continue; // Already listening to this conversation
        }

        final subscription = _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .snapshots()
            .listen((messagesSnapshot) async {
          if (messagesSnapshot.docs.isEmpty) return;

          final messageDoc = messagesSnapshot.docs.first;
          final messageId = messageDoc.id;
          final messageData = messageDoc.data();

          // Skip if we've already processed this message
          if (_knownMessageIds.contains(messageId)) return;

          final senderId = messageData['senderId'] as String?;
          if (senderId == null || senderId == user.uid) {
            // Don't notify for own messages
            _knownMessageIds.add(messageId);
            return;
          }

          // Get sender name
          String senderName = 'Someone';
          try {
            final senderProfile = await _userProfileService.getUserByUid(senderId);
            senderName = senderProfile?.name ?? 
                        senderProfile?.displayName ?? 
                        senderProfile?.email?.split('@').first ?? 
                        'Someone';
          } catch (e) {
            debugPrint('NotificationManager: Error getting sender profile: $e');
          }

          final text = messageData['text'] as String? ?? '';
          final locationId = messageData['locationId'] as String?;
          final momentId = messageData['momentId'] as String?;

          // Create notification based on message type
          if (momentId != null) {
            // Moment shared
            await _notificationService.showNotification(
              'New Moment Shared',
              '$senderName shared a moment with you',
              type: 'message',
              data: {
                'conversationId': conversationId,
                'momentId': momentId,
                'senderId': senderId,
              },
            );
          } else if (locationId != null) {
            // Scene/location shared
            await _notificationService.showNotification(
              'New Scene Shared',
              '$senderName sent you a scene',
              type: 'message',
              data: {
                'conversationId': conversationId,
                'locationId': locationId,
                'senderId': senderId,
              },
            );
          } else {
            // Regular text message
            await _notificationService.showNotification(
              'New Message',
              '$senderName: ${text.length > 50 ? text.substring(0, 50) + "..." : text}',
              type: 'message',
              data: {
                'conversationId': conversationId,
                'senderId': senderId,
              },
            );
          }

          _knownMessageIds.add(messageId);
          debugPrint('NotificationManager: Created notification for message $messageId');
        });
        
        _messageSubscriptions[conversationId] = subscription;
        debugPrint('NotificationManager: Added listener for conversation $conversationId');
      }

      // Store known conversation IDs to track initial load
      if (_knownMessageIds.isEmpty) {
        // First load - mark all existing messages as known
        for (final conversationDoc in conversationsSnapshot.docs) {
          final conversationId = conversationDoc.id;
          try {
            final messagesSnapshot = await _firestore
                .collection('conversations')
                .doc(conversationId)
                .collection('messages')
                .limit(10)
                .get();
            
            for (final messageDoc in messagesSnapshot.docs) {
              _knownMessageIds.add(messageDoc.id);
            }
          } catch (e) {
            debugPrint('NotificationManager: Error loading existing messages: $e');
          }
        }
        debugPrint('NotificationManager: Marked ${_knownMessageIds.length} existing messages as known');
      }
    });
  }

  /// Listen to new moment invites
  void _listenToMoments() {
    final user = _auth.currentUser;
    if (user == null) return;

    debugPrint('NotificationManager: Setting up moments listener...');

    _momentsSubscription = _firestore
        .collection('moments')
        .where('invitedFriends', arrayContains: user.uid)
        .snapshots()
        .listen((snapshot) async {
      if (_knownMomentInviteIds.isEmpty) {
        // First load - mark all existing invites as known
        for (final doc in snapshot.docs) {
          _knownMomentInviteIds.add(doc.id);
        }
        debugPrint('NotificationManager: Marked ${_knownMomentInviteIds.length} existing moment invites as known');
        return;
      }

      for (final doc in snapshot.docs) {
        final momentId = doc.id;
        
        // Skip if we've already processed this moment
        if (_knownMomentInviteIds.contains(momentId)) continue;

        final momentData = doc.data();
        final createdBy = momentData['createdBy'] as String?;
        final title = momentData['title'] as String? ?? 'A moment';
        
        if (createdBy == null || createdBy == user.uid) {
          // Don't notify for own moments
          _knownMomentInviteIds.add(momentId);
          continue;
        }

        // Get creator name
        String creatorName = 'Someone';
        try {
          final creatorProfile = await _userProfileService.getUserByUid(createdBy);
          creatorName = creatorProfile?.name ?? 
                       creatorProfile?.displayName ?? 
                       creatorProfile?.email?.split('@').first ?? 
                       'Someone';
        } catch (e) {
          debugPrint('NotificationManager: Error getting creator profile: $e');
        }

        await _notificationService.showNotification(
          'New Moment Invite',
          '$creatorName invited you to "$title"',
          type: 'moment_invite',
          data: {
            'momentId': momentId,
            'creatorId': createdBy,
          },
        );

        _knownMomentInviteIds.add(momentId);
        debugPrint('NotificationManager: Created notification for moment $momentId');
      }
    });
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
}
