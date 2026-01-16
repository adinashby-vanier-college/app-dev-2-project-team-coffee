import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'notification_service.dart';
import 'user_profile_service.dart';

enum FriendRequestStatus {
  pending,
  accepted,
  declined,
}

class FriendRequest {
  final String id;
  final String fromUid;
  final String toUid;
  final FriendRequestStatus status;
  final DateTime createdAt;

  FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.status,
    required this.createdAt,
  });

  factory FriendRequest.fromFirestore(Map<String, dynamic> data, String id) {
    return FriendRequest(
      id: id,
      fromUid: data['fromUid'] as String,
      toUid: data['toUid'] as String,
      status: FriendRequestStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'] as String,
        orElse: () => FriendRequestStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}

class FriendsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  final UserProfileService _userProfileService = UserProfileService();

  /// Sends a friend request from the current user to another user.
  Future<void> sendFriendRequest(String toUid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    if (currentUser.uid == toUid) {
      throw Exception('Cannot send friend request to yourself');
    }

    // Check if a request already exists from current user to target
    final requestFromMe = await _firestore
        .collection('friendRequests')
        .where('fromUid', isEqualTo: currentUser.uid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (requestFromMe.docs.isNotEmpty) {
      throw Exception('Friend request already sent');
    }

    // Check if a request already exists from target to current user
    final requestToMe = await _firestore
        .collection('friendRequests')
        .where('fromUid', isEqualTo: toUid)
        .where('toUid', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (requestToMe.docs.isNotEmpty) {
      throw Exception('Friend request already received from this user');
    }

    // Check if target user exists in Firestore
    final targetUserDoc = await _firestore
        .collection('users')
        .doc(toUid)
        .get();
    
    if (!targetUserDoc.exists) {
      throw Exception('User not found. The user may need to sign in to create their profile.');
    }

    // Check if they are already friends
    final currentUserDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();
    
    if (!currentUserDoc.exists) {
      throw Exception('Your profile is not set up. Please sign out and sign in again.');
    }
    
    final friendsList = currentUserDoc.data()?['friends'] as List<dynamic>? ?? [];
    if (friendsList.contains(toUid)) {
      throw Exception('Already friends');
    }

    // Create the friend request
    await _firestore.collection('friendRequests').add({
      'fromUid': currentUser.uid,
      'toUid': toUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Create notification for the recipient
    try {
      final senderProfile = await _userProfileService.getUserByUid(currentUser.uid);
      final senderName = senderProfile?.name ?? 
                        senderProfile?.displayName ?? 
                        senderProfile?.email?.split('@').first ?? 
                        'Someone';
      
      await _notificationService.storeNotificationForUser(
        toUid,
        'New Friend Request',
        '$senderName sent you a friend request',
        type: 'friend_request',
        data: {
          'fromUid': currentUser.uid,
        },
      );
      debugPrint('FriendsService: Created notification for friend request recipient $toUid');
    } catch (e) {
      debugPrint('FriendsService: Error creating notification for friend request: $e');
      // Don't fail the friend request if notification creation fails
    }
  }

  /// Accepts a friend request.
  /// Removes the request and adds both users to each other's friends list.
  Future<void> acceptFriendRequest(String requestId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    final requestDoc = await _firestore
        .collection('friendRequests')
        .doc(requestId)
        .get();

    if (!requestDoc.exists) {
      throw Exception('Friend request not found');
    }

    final requestData = requestDoc.data()!;
    final fromUid = requestData['fromUid'] as String;
    final toUid = requestData['toUid'] as String;

    if (toUid != currentUser.uid) {
      throw Exception('Not authorized to accept this request');
    }

    if (requestData['status'] != 'pending') {
      throw Exception('Friend request is not pending');
    }

    // Use batch write to ensure atomicity
    final batch = _firestore.batch();

    // Update request status to accepted
    batch.update(
      _firestore.collection('friendRequests').doc(requestId),
      {'status': 'accepted'},
    );

    // Add to current user's friends list
    batch.update(
      _firestore.collection('users').doc(currentUser.uid),
      {
        'friends': FieldValue.arrayUnion([fromUid]),
      },
    );

    // Add current user to requester's friends list
    batch.update(
      _firestore.collection('users').doc(fromUid),
      {
        'friends': FieldValue.arrayUnion([currentUser.uid]),
      },
    );

    try {
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to accept friend request: $e');
    }
  }

  /// Declines a friend request.
  /// Removes the request without creating a friendship.
  Future<void> declineFriendRequest(String requestId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    final requestDoc = await _firestore
        .collection('friendRequests')
        .doc(requestId)
        .get();

    if (!requestDoc.exists) {
      throw Exception('Friend request not found');
    }

    final requestData = requestDoc.data()!;
    final toUid = requestData['toUid'] as String;

    if (toUid != currentUser.uid) {
      throw Exception('Not authorized to decline this request');
    }

    // Update request status to declined
    await _firestore.collection('friendRequests').doc(requestId).update({
      'status': 'declined',
    });
  }

  /// Gets all pending friend requests received by the current user.
  Stream<List<FriendRequest>> getPendingFriendRequests() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('friendRequests')
        .where('toUid', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FriendRequest.fromFirestore(
                doc.data(),
                doc.id,
              ))
          .toList();
    });
  }

  /// Gets the list of friend UIDs for the current user.
  /// Gets the list of friend UIDs for the current user once.
  Future<List<String>> getFriendsListOnce() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('LOG-FRIENDS: getFriendsListOnce called but currentUser is NULL');
      return [];
    }
    debugPrint('LOG-FRIENDS: getFriendsListOnce called for user ${currentUser.uid}');

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (!snapshot.exists) {
        debugPrint('LOG-FRIENDS: User document does not exist for ${currentUser.uid}');
        return [];
      }
      
      final data = snapshot.data()!;
      final friends = data['friends'] as List<dynamic>? ?? [];
      final result = friends.map((e) => e.toString()).toList();
      debugPrint('LOG-FRIENDS: Found ${result.length} friends for ${currentUser.uid}');
      return result;
    } catch (e) {
      debugPrint('LOG-FRIENDS: Error fetching friends list: $e');
      return [];
    }
  }

  /// Gets the list of friend UIDs for the current user.
  Stream<List<String>> getFriendsList() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('LOG-FRIENDS: getFriendsList called but currentUser is NULL');
      return Stream.value([]);
    }
    debugPrint('LOG-FRIENDS: getFriendsList called for user ${currentUser.uid}');

    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return [];
      }
      final data = snapshot.data()!;
      final friends = data['friends'] as List<dynamic>? ?? [];
      return friends.map((e) => e.toString()).toList();
    });
  }

  /// Gets user profiles for a list of friend UIDs.
  Future<List<UserModel>> getFriendProfiles(List<String> friendUids) async {
    if (friendUids.isEmpty) {
      debugPrint('LOG-FRIENDS: getFriendProfiles called with empty friendUids');
      return [];
    }

    debugPrint('LOG-FRIENDS: getFriendProfiles called with ${friendUids.length} friend UIDs');

    // Firestore 'in' queries are limited to 10 items, so we need to batch
    final List<UserModel> profiles = [];
    try {
      for (var i = 0; i < friendUids.length; i += 10) {
        final batch = friendUids.skip(i).take(10).toList();
        debugPrint('LOG-FRIENDS: Querying batch ${i ~/ 10 + 1} with ${batch.length} UIDs');
        
        final snapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        debugPrint('LOG-FRIENDS: Batch query returned ${snapshot.docs.length} documents');
        
        for (var doc in snapshot.docs) {
          try {
            profiles.add(UserModel.fromFirestore(doc.data()!, doc.id));
          } catch (e) {
            debugPrint('LOG-FRIENDS: Error parsing user ${doc.id}: $e');
          }
        }
      }
      
      debugPrint('LOG-FRIENDS: getFriendProfiles returning ${profiles.length} profiles');
      return profiles;
    } catch (e, stackTrace) {
      debugPrint('LOG-FRIENDS: ERROR in getFriendProfiles: $e');
      debugPrint('LOG-FRIENDS: Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Stream of friend profiles for the current user.
  Stream<List<UserModel>> getFriendProfilesStream() {
    return getFriendsList().asyncMap((friendUids) async {
      return await getFriendProfiles(friendUids);
    });
  }

  /// Removes a friend relationship between the current user and another user.
  /// Removes both users from each other's friends list.
  Future<void> unfriend(String friendUid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    if (currentUser.uid == friendUid) {
      throw Exception('Cannot unfriend yourself');
    }

    // Check if they are actually friends
    final currentUserDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();
    
    if (!currentUserDoc.exists) {
      throw Exception('Your profile is not set up. Please sign out and sign in again.');
    }
    
    final friendsList = currentUserDoc.data()?['friends'] as List<dynamic>? ?? [];
    if (!friendsList.contains(friendUid)) {
      throw Exception('Not friends with this user');
    }

    // Use batch write to ensure atomicity
    final batch = _firestore.batch();

    // Remove from current user's friends list
    batch.update(
      _firestore.collection('users').doc(currentUser.uid),
      {
        'friends': FieldValue.arrayRemove([friendUid]),
      },
    );

    // Remove current user from friend's friends list
    batch.update(
      _firestore.collection('users').doc(friendUid),
      {
        'friends': FieldValue.arrayRemove([currentUser.uid]),
      },
    );

    try {
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to unfriend user: $e');
    }
  }
}


