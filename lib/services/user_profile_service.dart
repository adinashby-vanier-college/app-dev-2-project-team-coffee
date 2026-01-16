import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Ensures a user document exists in Firestore for the currently authenticated user.
  /// Creates the document if it doesn't exist, using the Auth UID as the document ID.
  Future<void> ensureUserDocumentExists() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    final userDocRef = _firestore.collection('users').doc(user.uid);
    final userDoc = await userDocRef.get();

    if (!userDoc.exists) {
      await userDocRef.set({
        'uid': user.uid,
        'email': (user.email ?? '').toLowerCase(), // Store lowercase for consistent searching
        'name': user.displayName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'friends': <String>[],
        'savedLocations': <String>[], // Initialize saved locations array
        'pinnedFriends': <String>[], // Initialize pinned friends array
      });
    }
  }

  /// Gets a user document from Firestore by UID.
  Future<UserModel?> getUserByUid(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      return null;
    }
    return UserModel.fromFirestore(userDoc.data()!, uid);
  }

  /// Gets the current authenticated user's profile from Firestore.
  Future<UserModel?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }
    return getUserByUid(user.uid);
  }

  /// Stream of the current user's profile from Firestore.
  Stream<UserModel?> getCurrentUserProfileStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }
    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return UserModel.fromFirestore(snapshot.data()!, user.uid);
    });
  }

  /// Searches for users by email.
  Future<List<UserModel>> searchUsersByEmail(String emailQuery) async {
    if (emailQuery.isEmpty) {
      return [];
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return [];
    }

    try {
      // Firestore doesn't support case-insensitive search, so we search for exact matches
      // or use a prefix search. For simplicity, we'll search for emails that start with the query.
      // Convert to lowercase for case-insensitive matching
      final lowerQuery = emailQuery.toLowerCase();
      final query = _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: lowerQuery)
          .where('email', isLessThan: lowerQuery + '\uf8ff')
          .limit(10);

      final snapshot = await query.get();
      return snapshot.docs
          .where((doc) => doc.id != currentUser.uid) // Exclude current user
          .map((doc) => UserModel.fromFirestore(doc.data()!, doc.id))
          .toList();
    } catch (e) {
      // If range query fails (needs index), try a simpler approach
      // Get all users and filter in memory (not ideal for large datasets, but works)
      try {
        final snapshot = await _firestore
            .collection('users')
            .limit(50) // Limit to prevent loading too many
            .get();
        
        final lowerQuery = emailQuery.toLowerCase();
        return snapshot.docs
            .where((doc) {
              final data = doc.data();
              final email = (data['email'] as String? ?? '').toLowerCase();
              return doc.id != currentUser.uid && 
                     email.contains(lowerQuery);
            })
            .map((doc) => UserModel.fromFirestore(doc.data(), doc.id))
            .take(10)
            .toList();
      } catch (fallbackError) {
        throw Exception('Search failed: $e (fallback also failed: $fallbackError)');
      }
    }
  }

  /// Updates the user's name in Firestore
  Future<void> updateUserName(String newName) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    await _firestore.collection('users').doc(user.uid).update({
      'name': newName,
    });
  }

  /// Updates the user's profile picture URL in Firestore
  Future<void> updateProfilePicture(String photoURL) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    await _firestore.collection('users').doc(user.uid).update({
      'photoURL': photoURL,
    });
  }

  /// Updates the user's location in Firestore
  Future<void> updateUserLocation(Map<String, dynamic> location) async {
    final user = _auth.currentUser;
    if (user == null) return; // Fail silently if not logged in

    await _firestore.collection('users').doc(user.uid).update({
      'location': location,
      'lastLocationUpdate': FieldValue.serverTimestamp(),
    });
  }

  /// Pins a friend to the user's pinned friends list (max 3)
  Future<void> pinFriend(String friendUid) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    // Get current pinned friends
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      throw Exception('User document not found');
    }

    final data = userDoc.data()!;
    final pinnedFriends = List<String>.from(data['pinnedFriends'] ?? []);

    // Check if already pinned
    if (pinnedFriends.contains(friendUid)) {
      return; // Already pinned, nothing to do
    }

    // Check if limit reached (max 3)
    if (pinnedFriends.length >= 3) {
      throw Exception('Maximum of 3 pinned friends allowed');
    }

    // Add to pinned friends
    pinnedFriends.add(friendUid);

    await _firestore.collection('users').doc(user.uid).update({
      'pinnedFriends': pinnedFriends,
    });
  }

  /// Unpins a friend from the user's pinned friends list
  Future<void> unpinFriend(String friendUid) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    await _firestore.collection('users').doc(user.uid).update({
      'pinnedFriends': FieldValue.arrayRemove([friendUid]),
    });
  }

  /// Gets the list of pinned friend UIDs for the current user
  Future<List<String>> getPinnedFriends() async {
    final user = _auth.currentUser;
    if (user == null) {
      return [];
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      return [];
    }

    final data = userDoc.data()!;
    return List<String>.from(data['pinnedFriends'] ?? []);
  }

  /// Stream of pinned friend UIDs for the current user
  Stream<List<String>> getPinnedFriendsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return [];
      }
      final data = snapshot.data()!;
      return List<String>.from(data['pinnedFriends'] ?? []);
    });
  }
}


