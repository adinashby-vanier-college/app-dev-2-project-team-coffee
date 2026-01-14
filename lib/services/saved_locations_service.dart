import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SavedLocationsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Saves a location ID to the user's saved locations list
  Future<void> saveLocation(String locationId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    await _firestore.collection('users').doc(user.uid).update({
      'savedLocations': FieldValue.arrayUnion([locationId]),
    });
  }

  /// Removes a location ID from the user's saved locations list
  Future<void> unsaveLocation(String locationId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    await _firestore.collection('users').doc(user.uid).update({
      'savedLocations': FieldValue.arrayRemove([locationId]),
    });
  }

  /// Gets the list of saved location IDs for the current user
  Future<List<String>> getSavedLocations() async {
    final user = _auth.currentUser;
    if (user == null) {
      return [];
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      return [];
    }

    final data = userDoc.data()!;
    final savedLocations = data['savedLocations'] as List<dynamic>? ?? [];
    return savedLocations.map((e) => e.toString()).toList();
  }

  /// Stream of saved location IDs for the current user
  Stream<List<String>> getSavedLocationsStream() {
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
      final savedLocations = data['savedLocations'] as List<dynamic>? ?? [];
      return savedLocations.map((e) => e.toString()).toList();
    });
  }
}
