import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/moment_model.dart';

class MomentsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String collectionName = 'moments';

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
      return Stream.value([]);
    }

    return _firestore
        .collection(collectionName)
        .where('createdBy', isEqualTo: user.uid)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MomentModel.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  /// Gets moments the current user is invited to
  /// This includes:
  /// 1. Moments where the user is in the invitedFriends array
  /// 2. Moments that were shared with the user in chat messages
  Stream<List<MomentModel>> getInvitedMomentsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    // Stream 1: Moments from invitedFriends array
    final invitedFriendsStream = _firestore
        .collection(collectionName)
        .where('invitedFriends', arrayContains: user.uid)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MomentModel.fromFirestore(doc.data(), doc.id))
          .toList();
    });

    // Stream 2: Moments shared in chat messages
    final chatMomentsStream = _getMomentsFromChatMessages(user.uid);

    // Combine both streams
    return _combineStreams(invitedFriendsStream, chatMomentsStream);
  }

  /// Gets moments that were shared with the user in chat messages
  Stream<List<MomentModel>> _getMomentsFromChatMessages(String userId) {
    final controller = StreamController<List<MomentModel>>();
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
          if (isInitialized) {
            controller.add(<MomentModel>[]);
          }
          isInitialized = true;
          return;
        }

        // Listen to messages in each conversation
        for (var conversationDoc in conversationsSnapshot.docs) {
          final conversationId = conversationDoc.id;
          
          final messagesSub = _firestore
              .collection('conversations')
              .doc(conversationId)
              .collection('messages')
              .snapshots()
              .listen(
            (messagesSnapshot) {
              // Update momentIds from messages
              for (var messageDoc in messagesSnapshot.docs) {
                final messageData = messageDoc.data();
                final senderId = messageData['senderId'] as String?;
                final momentId = messageData['momentId'] as String?;

                // Only include moments sent TO the user (not by the user)
                if (momentId != null && senderId != null && senderId != userId) {
                  momentIds.add(momentId);
                }
              }
              
              // Debounce to avoid multiple simultaneous fetches
              debounceTimer?.cancel();
              debounceTimer = Timer(const Duration(milliseconds: 300), () {
                _fetchAndEmitMoments(momentIds, userId, controller);
              });
            },
            onError: (error) {
              debugPrint('MomentsService: Error in message stream for conversation $conversationId: $error');
            },
          );
          
          subscriptions.add(messagesSub);
        }
        
        isInitialized = true;
      },
      onError: (error) {
        debugPrint('MomentsService: Error in conversations stream: $error');
        controller.addError(error);
      },
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
    final moments = <MomentModel>[];
    for (var momentId in momentIds) {
      try {
        final momentDoc = await _firestore
            .collection(collectionName)
            .doc(momentId)
            .get();

        if (momentDoc.exists) {
          final moment = MomentModel.fromFirestore(momentDoc.data()!, momentDoc.id);
          // Only include if the user didn't create it (to avoid duplicates with "My Moments")
          if (moment.createdBy != userId) {
            moments.add(moment);
          }
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
    final controller = StreamController<List<MomentModel>>();
    final latest1 = <MomentModel>[];
    final latest2 = <MomentModel>[];
    bool hasData1 = false;
    bool hasData2 = false;

    StreamSubscription? sub1;
    StreamSubscription? sub2;

    void emitCombined() {
      if (hasData1 || hasData2) {
        // Combine and remove duplicates by ID
        final combined = <String, MomentModel>{};
        
        for (var moment in latest1) {
          combined[moment.id] = moment;
        }
        
        for (var moment in latest2) {
          combined[moment.id] = moment;
        }

        final result = combined.values.toList();
        result.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        controller.add(result);
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
        controller.addError(error);
      },
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
        controller.addError(error);
      },
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
