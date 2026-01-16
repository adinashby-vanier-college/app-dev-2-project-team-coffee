import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/moment_model.dart';
import 'notification_service.dart';
import 'user_profile_service.dart';

class MomentsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  final UserProfileService _userProfileService = UserProfileService();
  static const String collectionName = 'moments';
  
  // Cache streams per user to avoid recreating them on tab switches
  StreamController<List<MomentModel>>? _cachedMyMomentsController;
  StreamController<List<MomentModel>>? _cachedInvitedMomentsController;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _cachedMyMomentsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _cachedInvitedFriendsSubscription;
  StreamSubscription<List<MomentModel>>? _cachedInvitedCombinedSubscription;
  List<MomentModel>? _cachedMyMomentsLatest;
  List<MomentModel>? _cachedInvitedMomentsLatest;
  String? _cachedUserId;

  /// Generates a unique share code
  String _generateShareCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Avoiding confusing chars like O, 0, I, 1
    final random = Random.secure();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Creates a new moment
  Future<String> createMoment({
    required String title,
    String? description,
    required String locationId,
    required String locationName,
    required String locationAddress,
    required DateTime dateTime,
    List<String> invitedFriends = const [],
    bool generateShareCode = true,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    final shareCode = generateShareCode ? _generateShareCode() : null;

    final moment = MomentModel(
      id: '', // Will be set by Firestore
      title: title,
      description: description,
      locationId: locationId,
      locationName: locationName,
      locationAddress: locationAddress,
      dateTime: dateTime,
      createdBy: user.uid,
      createdAt: DateTime.now(),
      shareCode: shareCode,
      invitedFriends: invitedFriends,
      responses: {user.uid: 'going'}, // Creator is automatically going
      guestResponses: [],
    );

    final docRef = await _firestore
        .collection(collectionName)
        .add(moment.toFirestore());

    debugPrint('MomentsService: Created moment ${docRef.id} with shareCode: $shareCode');
    return docRef.id;
  }

  /// Gets moments created by the current user
  Stream<List<MomentModel>> getMyMomentsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      _cleanupCachedStreams();
      return Stream.value([]);
    }

    // Return cached stream if user hasn't changed
    if (_cachedMyMomentsController != null && _cachedUserId == user.uid) {
      return _cachedMyMomentsController!.stream;
    }

    // Cleanup old streams if user changed
    if (_cachedUserId != null && _cachedUserId != user.uid) {
      _cleanupCachedStreams();
    }

    // Create new stream controller and cache it
    _cachedUserId = user.uid;
    _cachedMyMomentsController = StreamController<List<MomentModel>>.broadcast();
    _cachedMyMomentsController!.onListen = () {
      if (_cachedMyMomentsLatest != null && !_cachedMyMomentsController!.isClosed) {
        _cachedMyMomentsController!.add(_cachedMyMomentsLatest!);
      }
    };
    
    _cachedMyMomentsSubscription = _firestore
        .collection(collectionName)
        .where('createdBy', isEqualTo: user.uid)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .listen(
      (snapshot) {
        if (_cachedMyMomentsController != null && !_cachedMyMomentsController!.isClosed) {
          try {
            final moments = snapshot.docs
                .map((doc) => MomentModel.fromFirestore(doc.data(), doc.id))
                .toList();
            _cachedMyMomentsLatest = moments;
            _cachedMyMomentsController!.add(moments);
          } catch (e) {
            debugPrint('MomentsService: Error mapping myMoments stream: $e');
            _cachedMyMomentsController!.add(<MomentModel>[]);
          }
        }
      },
      onError: (error) {
        debugPrint('MomentsService: Error in getMyMomentsStream: $error');
        if (_cachedMyMomentsController != null && !_cachedMyMomentsController!.isClosed) {
          _cachedMyMomentsController!.add(<MomentModel>[]);
        }
      },
      cancelOnError: false,
    );
    
    _cachedMyMomentsController!.onCancel = () {};
    
    return _cachedMyMomentsController!.stream;
  }
  
  void _cleanupCachedStreams() {
    _cachedMyMomentsSubscription?.cancel();
    _cachedInvitedFriendsSubscription?.cancel();
    _cachedInvitedCombinedSubscription?.cancel();
    _cachedMyMomentsController?.close();
    _cachedInvitedMomentsController?.close();
    _cachedMyMomentsSubscription = null;
    _cachedInvitedFriendsSubscription = null;
    _cachedInvitedCombinedSubscription = null;
    _cachedMyMomentsController = null;
    _cachedInvitedMomentsController = null;
    _cachedMyMomentsLatest = null;
    _cachedInvitedMomentsLatest = null;
    _cachedUserId = null;
  }

  /// Gets moments the current user is invited to
  /// This includes:
  /// 1. Moments where the user is in the invitedFriends array
  /// 2. Moments that were shared with the user in chat messages
  Stream<List<MomentModel>> getInvitedMomentsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      _cleanupCachedStreams();
      return Stream.value([]);
    }

    // Return cached stream if user hasn't changed
    if (_cachedInvitedMomentsController != null && _cachedUserId == user.uid) {
      return _cachedInvitedMomentsController!.stream;
    }

    // Cleanup old streams if user changed
    if (_cachedUserId != null && _cachedUserId != user.uid) {
      _cleanupCachedStreams();
    }

    // Create new streams and cache the combined result
    _cachedUserId = user.uid;
    
    // Stream 1: Moments from invitedFriends array
    final invitedFriendsController = StreamController<List<MomentModel>>.broadcast();
    
    _cachedInvitedFriendsSubscription = _firestore
        .collection(collectionName)
        .where('invitedFriends', arrayContains: user.uid)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .listen(
      (snapshot) {
        if (invitedFriendsController.isClosed) return;
        try {
          final moments = snapshot.docs
              .map((doc) => MomentModel.fromFirestore(doc.data(), doc.id))
              .toList();
          invitedFriendsController.add(moments);
        } catch (e) {
          debugPrint('MomentsService: Error mapping invitedFriends stream: $e');
          invitedFriendsController.add(<MomentModel>[]);
        }
      },
      onError: (error) {
        debugPrint('MomentsService: Error in invitedFriendsStream: $error');
        if (!invitedFriendsController.isClosed) {
          invitedFriendsController.add(<MomentModel>[]);
        }
      },
      cancelOnError: false,
    );
    
    invitedFriendsController.onCancel = () {};
    
    final invitedFriendsStream = invitedFriendsController.stream;

    // Stream 2: Moments shared in chat messages
    final chatMomentsStream = _getMomentsFromChatMessages(user.uid);

    // Combine both streams and cache the result
    final combinedStream = _combineStreams(invitedFriendsStream, chatMomentsStream);
    _cachedInvitedMomentsController = StreamController<List<MomentModel>>.broadcast();
    _cachedInvitedMomentsController!.onListen = () {
      if (_cachedInvitedMomentsLatest != null && !_cachedInvitedMomentsController!.isClosed) {
        _cachedInvitedMomentsController!.add(_cachedInvitedMomentsLatest!);
      }
    };
    
    _cachedInvitedCombinedSubscription = combinedStream.listen(
      (moments) {
        if (_cachedInvitedMomentsController != null && !_cachedInvitedMomentsController!.isClosed) {
          _cachedInvitedMomentsLatest = moments;
          _cachedInvitedMomentsController!.add(moments);
        }
      },
      onError: (error) {
        debugPrint('MomentsService: Error in combined invited stream: $error');
        if (_cachedInvitedMomentsController != null && !_cachedInvitedMomentsController!.isClosed) {
          _cachedInvitedMomentsController!.add(<MomentModel>[]);
        }
      },
      cancelOnError: false,
    );
    
    _cachedInvitedMomentsController!.onCancel = () {};
    
    return _cachedInvitedMomentsController!.stream;
  }

  /// Gets moments that were shared with the user in chat messages
  Stream<List<MomentModel>> _getMomentsFromChatMessages(String userId) {
    final controller = StreamController<List<MomentModel>>.broadcast();
    final subscriptions = <StreamSubscription>[];
    final momentIds = <String>{};
    bool isInitialized = false;
    Timer? debounceTimer;

    // Listen to conversations
    final conversationsSub = _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .snapshots()
        .listen(
      (conversationsSnapshot) {
        // Cancel previous message subscriptions
        for (var sub in subscriptions) {
          sub.cancel();
        }
        subscriptions.clear();
        momentIds.clear();
        debounceTimer?.cancel();

        if (conversationsSnapshot.docs.isEmpty) {
          // No conversations, emit empty list and mark as initialized
          isInitialized = true;
          if (!controller.isClosed) {
            controller.add(<MomentModel>[]);
          }
          return;
        }

        // Listen to messages in each conversation
        final initializedListeners = <String>{}; // Track which conversation listeners have fired
        final conversationMomentIds = <String, Set<String>>{}; // Track momentIds per conversation
        bool hasSetUpListeners = false;
        
        void rebuildAndEmitMoments() {
          // Rebuild complete set of momentIds from all conversations
          final allMomentIds = <String>{};
          for (var ids in conversationMomentIds.values) {
            allMomentIds.addAll(ids);
          }
          
          // Use debounce to avoid excessive fetches
          debounceTimer?.cancel();
          debounceTimer = Timer(const Duration(milliseconds: 300), () {
            _fetchAndEmitMoments(allMomentIds, userId, controller);
          });
        }
        
        for (var conversationDoc in conversationsSnapshot.docs) {
          final conversationId = conversationDoc.id;
          conversationMomentIds[conversationId] = <String>{};
          
          final messagesSub = _firestore
              .collection('conversations')
              .doc(conversationId)
              .collection('messages')
              .snapshots()
              .listen(
            (messagesSnapshot) {
              // Mark this listener as initialized
              initializedListeners.add(conversationId);
              
              // Update momentIds for this conversation
              final thisConversationMoments = <String>{};
              for (var messageDoc in messagesSnapshot.docs) {
                final messageData = messageDoc.data();
                final senderId = messageData['senderId'] as String?;
                final momentId = messageData['momentId'] as String?;

                // Only include moments sent TO the user (not by the user)
                if (momentId != null && senderId != null && senderId != userId) {
                  thisConversationMoments.add(momentId);
                }
              }
              
              // Update the momentIds for this conversation
              conversationMomentIds[conversationId] = thisConversationMoments;
              
              // After all listeners have fired at least once, fetch and emit
              if (!hasSetUpListeners && initializedListeners.length >= conversationsSnapshot.docs.length) {
                hasSetUpListeners = true;
                isInitialized = true;
                rebuildAndEmitMoments();
              } else if (hasSetUpListeners) {
                // Subsequent updates
                rebuildAndEmitMoments();
              }
            },
            onError: (error) {
              debugPrint('MomentsService: Error in message stream for conversation $conversationId: $error');
              // Mark as initialized even on error
              initializedListeners.add(conversationId);
              conversationMomentIds[conversationId] = <String>{}; // Empty set on error
              // If this was the last listener and we haven't initialized yet, emit empty
              if (!hasSetUpListeners && initializedListeners.length >= conversationsSnapshot.docs.length) {
                hasSetUpListeners = true;
                isInitialized = true;
                rebuildAndEmitMoments();
              } else if (hasSetUpListeners) {
                rebuildAndEmitMoments();
              }
            },
          );
          
          subscriptions.add(messagesSub);
        }
      },
      onError: (error) {
        debugPrint('MomentsService: Error in conversations stream: $error');
        // Instead of adding error, emit empty list and mark as initialized
        isInitialized = true;
        if (!controller.isClosed) {
          controller.add(<MomentModel>[]);
        }
      },
      cancelOnError: false,
    );

    controller.onCancel = () {
      conversationsSub.cancel();
      for (var sub in subscriptions) {
        sub.cancel();
      }
      debounceTimer?.cancel();
    };

    return controller.stream;
  }

  /// Fetches moments by their IDs and emits them
  Future<void> _fetchAndEmitMoments(
    Set<String> momentIds,
    String userId,
    StreamController<List<MomentModel>> controller,
  ) async {
    if (momentIds.isEmpty) {
      controller.add(<MomentModel>[]);
      return;
    }

    // Fetch all moments by their IDs
    // Include ALL moments shared in chat, even if user created them originally
    // (e.g., if user sends moment to friend, friend sends it back - it should appear in Invited)
    // Duplicates with "My Moments" are handled by the _combineStreams method which removes duplicates by ID
    final moments = <MomentModel>[];
    for (var momentId in momentIds) {
      try {
        final momentDoc = await _firestore
            .collection(collectionName)
            .doc(momentId)
            .get();

        if (momentDoc.exists) {
          final moment = MomentModel.fromFirestore(momentDoc.data()!, momentDoc.id);
          // Include all moments shared via chat, regardless of creator
          moments.add(moment);
        }
      } catch (e) {
        debugPrint('MomentsService: Error fetching moment $momentId: $e');
        // Continue with other moments
      }
    }

    // Sort by dateTime
    moments.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    controller.add(moments);
  }

  /// Combines two streams of moment lists, removing duplicates
  Stream<List<MomentModel>> _combineStreams(
    Stream<List<MomentModel>> stream1,
    Stream<List<MomentModel>> stream2,
  ) {
    final controller = StreamController<List<MomentModel>>.broadcast();
    final latest1 = <MomentModel>[];
    final latest2 = <MomentModel>[];
    bool hasData1 = false;
    bool hasData2 = false;
    bool hasEmitted = false;

    StreamSubscription? sub1;
    StreamSubscription? sub2;

    void emitCombined() {
      // Always emit if we have data from at least one stream
      // This ensures empty lists are also emitted, allowing StreamBuilder to resolve
      if (hasData1 || hasData2) {
        // Combine and remove duplicates by ID
        final combined = <String, MomentModel>{};
        
        if (hasData1) {
          for (var moment in latest1) {
            combined[moment.id] = moment;
          }
        }
        
        if (hasData2) {
          for (var moment in latest2) {
            combined[moment.id] = moment;
          }
        }

        final result = combined.values.toList();
        result.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        controller.add(result);
        hasEmitted = true;
      }
    }
    
    sub1 = stream1.listen(
      (moments) {
        latest1.clear();
        latest1.addAll(moments);
        hasData1 = true;
        emitCombined();
      },
      onError: (error) {
        debugPrint('MomentsService: Error in stream1: $error');
        // Emit empty list on error instead of passing error through
        latest1.clear();
        hasData1 = true;
        emitCombined();
      },
      onDone: () {
        debugPrint('MomentsService: stream1 done');
      },
      cancelOnError: false, // Don't cancel subscription on error
    );

    sub2 = stream2.listen(
      (moments) {
        latest2.clear();
        latest2.addAll(moments);
        hasData2 = true;
        emitCombined();
      },
      onError: (error) {
        debugPrint('MomentsService: Error in stream2: $error');
        // Emit empty list on error instead of passing error through
        latest2.clear();
        hasData2 = true;
        emitCombined();
      },
      onDone: () {
        debugPrint('MomentsService: stream2 done');
      },
      cancelOnError: false, // Don't cancel subscription on error
    );

    controller.onCancel = () {
      sub1?.cancel();
      sub2?.cancel();
    };

    return controller.stream;
  }

  /// Gets a single moment by ID
  Future<MomentModel?> getMomentById(String momentId) async {
    final doc = await _firestore
        .collection(collectionName)
        .doc(momentId)
        .get();

    if (!doc.exists) {
      return null;
    }

    return MomentModel.fromFirestore(doc.data()!, doc.id);
  }

  /// Gets a moment by share code (for web form access)
  Future<MomentModel?> getMomentByShareCode(String shareCode) async {
    final snapshot = await _firestore
        .collection(collectionName)
        .where('shareCode', isEqualTo: shareCode)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final doc = snapshot.docs.first;
    return MomentModel.fromFirestore(doc.data(), doc.id);
  }

  /// Updates RSVP response for the current user
  Future<void> updateResponse(String momentId, String response) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    await _firestore
        .collection(collectionName)
        .doc(momentId)
        .update({
      'responses.${user.uid}': response,
    });

    debugPrint('MomentsService: Updated response to $response for moment $momentId');
  }

  /// Adds a guest response (from web form, non-app user)
  Future<void> addGuestResponse({
    required String momentId,
    required String guestName,
    required String response,
    String? email,
    String? note,
  }) async {
    final guestResponse = {
      'name': guestName,
      'response': response,
      'email': email,
      'note': note,
      'respondedAt': Timestamp.now(),
    };

    await _firestore
        .collection(collectionName)
        .doc(momentId)
        .update({
      'guestResponses': FieldValue.arrayUnion([guestResponse]),
    });

    debugPrint('MomentsService: Added guest response from $guestName to moment $momentId');
  }

  /// Invites friends to a moment
  Future<void> inviteFriends(String momentId, List<String> friendIds) async {
    if (friendIds.isEmpty) {
      debugPrint('MomentsService: No friends to invite for moment $momentId');
      return;
    }
    
    debugPrint('MomentsService: Inviting ${friendIds.length} friends to moment $momentId: $friendIds');
    
    await _firestore
        .collection(collectionName)
        .doc(momentId)
        .update({
      'invitedFriends': FieldValue.arrayUnion(friendIds),
    });

    debugPrint('MomentsService: Successfully invited ${friendIds.length} friends to moment $momentId');
    
    // Create notifications for each invited friend
    final moment = await getMomentById(momentId);
    if (moment != null) {
      final creatorProfile = await _userProfileService.getUserByUid(moment.createdBy);
      final creatorName = creatorProfile?.name ?? 
                         creatorProfile?.displayName ?? 
                         creatorProfile?.email?.split('@').first ?? 
                         'Someone';
      
      for (final friendId in friendIds) {
        try {
          await _notificationService.storeNotificationForUser(
            friendId,
            'New Moment Invite',
            '$creatorName invited you to "${moment.title}"',
            type: 'moment_invite',
            data: {
              'momentId': momentId,
              'creatorId': moment.createdBy,
            },
          );
          debugPrint('MomentsService: Created notification for friend $friendId');
        } catch (e) {
          debugPrint('MomentsService: Error creating notification for friend $friendId: $e');
          // Don't fail the invite if notification creation fails
        }
      }
    }
    
    // Verify the update
    try {
      final updatedDoc = await _firestore
          .collection(collectionName)
          .doc(momentId)
          .get();
      if (updatedDoc.exists) {
        final data = updatedDoc.data();
        final invitedFriends = data?['invitedFriends'] as List<dynamic>? ?? [];
        debugPrint('MomentsService: Moment $momentId now has ${invitedFriends.length} invited friends: $invitedFriends');
      }
    } catch (e) {
      debugPrint('MomentsService: Error verifying invite update: $e');
    }
  }

  /// Regenerates the share code for a moment
  Future<String> regenerateShareCode(String momentId) async {
    final newShareCode = _generateShareCode();
    
    await _firestore
        .collection(collectionName)
        .doc(momentId)
        .update({'shareCode': newShareCode});

    debugPrint('MomentsService: Regenerated share code to $newShareCode for moment $momentId');
    return newShareCode;
  }

  /// Deletes a moment (only owner can delete)
  Future<void> deleteMoment(String momentId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    final moment = await getMomentById(momentId);
    if (moment == null) {
      throw Exception('Moment not found');
    }

    if (moment.createdBy != user.uid) {
      throw Exception('Only the creator can delete this moment');
    }

    await _firestore
        .collection(collectionName)
        .doc(momentId)
        .delete();

    debugPrint('MomentsService: Deleted moment $momentId');
  }

  /// Updates a moment
  Future<void> updateMoment(
    String momentId, {
    String? title,
    String? description,
    DateTime? dateTime,
  }) async {
    final updates = <String, dynamic>{};
    
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (dateTime != null) updates['dateTime'] = Timestamp.fromDate(dateTime);

    if (updates.isEmpty) return;

    await _firestore
        .collection(collectionName)
        .doc(momentId)
        .update(updates);

    debugPrint('MomentsService: Updated moment $momentId');
  }
}
