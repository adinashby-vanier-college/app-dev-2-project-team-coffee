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
  final Map<String, DateTime> _latestMessageTimestamps = {}; // Track latest message time per conversation
  DateTime _initializationTime = DateTime.now(); // Track when we started listening
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
    _initializationTime = DateTime.now().subtract(const Duration(seconds: 10)); // Give 10s buffer

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
    _latestMessageTimestamps.clear();
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

          // Check message timestamp - only notify if message is new (after initialization time)
          final messageTimestamp = (messageData['timestamp'] as Timestamp?)?.toDate();
          if (messageTimestamp != null) {
            // If message is older than initialization time, skip it (it's an old message we already know about)
            if (messageTimestamp.isBefore(_initializationTime)) {
              _knownMessageIds.add(messageId);
              return;
            }
            
            // Track the latest timestamp for this conversation
            final currentLatest = _latestMessageTimestamps[conversationId];
            if (currentLatest != null && messageTimestamp.isBefore(currentLatest)) {
              // This message is older than what we've seen, skip it
              _knownMessageIds.add(messageId);
              return;
            }
            _latestMessageTimestamps[conversationId] = messageTimestamp;
          }

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

      // Store known conversation IDs and latest timestamps for initial load
      if (_knownMessageIds.isEmpty) {
        // First load - mark all existing messages as known and track latest timestamps
        for (final conversationDoc in conversationsSnapshot.docs) {
          final conversationId = conversationDoc.id;
          try {
            final messagesSnapshot = await _firestore
                .collection('conversations')
                .doc(conversationId)
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .limit(10)
                .get();
            
            DateTime? latestTimestamp;
            for (final messageDoc in messagesSnapshot.docs) {
              _knownMessageIds.add(messageDoc.id);
              
              // Track the latest message timestamp for this conversation
              final timestamp = (messageDoc.data()['timestamp'] as Timestamp?)?.toDate();
              if (timestamp != null) {
                if (latestTimestamp == null || timestamp.isAfter(latestTimestamp)) {
                  latestTimestamp = timestamp;
                }
              }
            }
            
            if (latestTimestamp != null) {
              _latestMessageTimestamps[conversationId] = latestTimestamp;
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

    debugPrint('NotificationManager: Setting up moments listener for user ${user.uid}...');

    _momentsSubscription = _firestore
        .collection('moments')
        .where('invitedFriends', arrayContains: user.uid)
        .snapshots()
        .listen((snapshot) async {
      debugPrint('NotificationManager: Moments snapshot received - ${snapshot.docChanges.length} changes, ${snapshot.docs.length} total docs');
      
      // On first load, mark all existing documents as known BEFORE processing changes
      if (_knownMomentInviteIds.isEmpty) {
        debugPrint('NotificationManager: First load - marking existing moments as known');
        for (final doc in snapshot.docs) {
          _knownMomentInviteIds.add(doc.id);
        }
        debugPrint('NotificationManager: Marked ${_knownMomentInviteIds.length} existing moment invites as known');
      }
      
      // Process document changes - check for new invites
      for (final change in snapshot.docChanges) {
        final momentId = change.doc.id;
        debugPrint('NotificationManager: Processing change - type: ${change.type}, momentId: $momentId');
        
        // Process added documents (new moments where user is invited, or existing moments where user was just added)
        if (change.type == DocumentChangeType.added) {
          // Skip if we've already processed this moment
          if (_knownMomentInviteIds.contains(momentId)) {
            debugPrint('NotificationManager: Moment $momentId already known, skipping');
            continue;
          }

          final momentData = change.doc.data();
          if (momentData == null) {
            debugPrint('NotificationManager: Moment $momentId has no data, marking as known');
            _knownMomentInviteIds.add(momentId);
            continue;
          }
          
          final createdBy = momentData['createdBy'] as String?;
          final title = momentData['title'] as String? ?? 'A moment';
          final invitedFriends = momentData['invitedFriends'] as List<dynamic>? ?? [];
          
          debugPrint('NotificationManager: Moment $momentId - createdBy: $createdBy, title: $title, invitedFriends: $invitedFriends');
          
          // Double-check that user is actually in invitedFriends
          if (!invitedFriends.contains(user.uid)) {
            debugPrint('NotificationManager: User not in invitedFriends for moment $momentId, skipping');
            _knownMomentInviteIds.add(momentId);
            continue;
          }
          
          // Check if this moment was created after our initialization time
          final createdAt = (momentData['createdAt'] as Timestamp?)?.toDate();
          if (createdAt != null && createdAt.isBefore(_initializationTime)) {
            // Old moment, mark as known but don't notify
            debugPrint('NotificationManager: Moment $momentId is old (created ${createdAt}), marking as known');
            _knownMomentInviteIds.add(momentId);
            continue;
          }
          
          if (createdBy == null || createdBy == user.uid) {
            // Don't notify for own moments
            debugPrint('NotificationManager: Moment $momentId is own moment or no creator, marking as known');
            _knownMomentInviteIds.add(momentId);
            continue;
          }

          debugPrint('NotificationManager: Creating notification for moment $momentId from $createdBy');
          
          // Get creator name
          String creatorName = 'Someone';
          try {
            final creatorProfile = await _userProfileService.getUserByUid(createdBy);
            creatorName = creatorProfile?.name ?? 
                         creatorProfile?.displayName ?? 
                         creatorProfile?.email?.split('@').first ?? 
                         'Someone';
            debugPrint('NotificationManager: Creator name resolved: $creatorName');
          } catch (e) {
            debugPrint('NotificationManager: Error getting creator profile: $e');
          }

          try {
            await _notificationService.showNotification(
              'New Moment Invite',
              '$creatorName invited you to "$title"',
              type: 'moment_invite',
              data: {
                'momentId': momentId,
                'creatorId': createdBy,
              },
            );
            debugPrint('NotificationManager: Successfully created notification for moment $momentId');
          } catch (e) {
            debugPrint('NotificationManager: Error creating notification: $e');
          }

          _knownMomentInviteIds.add(momentId);
        } else if (change.type == DocumentChangeType.modified) {
          // Modified documents - check if user was just added to invitedFriends
          // Note: This case is less common because when arrayUnion adds a user, 
          // if the document wasn't matching the query before, it appears as "added"
          final momentData = change.doc.data();
          if (momentData == null) {
            debugPrint('NotificationManager: Modified moment $momentId has no data');
            continue;
          }
          
          final invitedFriends = momentData['invitedFriends'] as List<dynamic>? ?? [];
          debugPrint('NotificationManager: Modified moment $momentId - invitedFriends: $invitedFriends');
          
          // If user is in invitedFriends and we haven't processed this moment yet
          if (invitedFriends.contains(user.uid) && !_knownMomentInviteIds.contains(momentId)) {
            debugPrint('NotificationManager: User added to modified moment $momentId');
            final createdBy = momentData['createdBy'] as String?;
            final title = momentData['title'] as String? ?? 'A moment';
            
            if (createdBy == null || createdBy == user.uid) {
              debugPrint('NotificationManager: Modified moment $momentId is own moment, marking as known');
              _knownMomentInviteIds.add(momentId);
              continue;
            }

            debugPrint('NotificationManager: Creating notification for modified moment $momentId from $createdBy');
            
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

            try {
              await _notificationService.showNotification(
                'New Moment Invite',
                '$creatorName invited you to "$title"',
                type: 'moment_invite',
                data: {
                  'momentId': momentId,
                  'creatorId': createdBy,
                },
              );
              debugPrint('NotificationManager: Successfully created notification for modified moment $momentId');
            } catch (e) {
              debugPrint('NotificationManager: Error creating notification for modified moment: $e');
            }

            _knownMomentInviteIds.add(momentId);
          }
        }
      }
    }, onError: (error) {
      debugPrint('NotificationManager: Error in moments listener: $error');
    });
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
}
