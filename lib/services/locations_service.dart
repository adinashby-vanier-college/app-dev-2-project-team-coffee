import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to manage locations in Firebase Firestore
class LocationsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String collectionName = 'locations';

  /// Uploads a location to Firebase with its ID as the document ID
  /// Requires authentication
  Future<void> uploadLocation(Map<String, dynamic> locationData) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Authentication required to upload locations');
    }

    final locationId = locationData['id'] as String;
    if (locationId.isEmpty) {
      throw Exception('Location ID is required');
    }

    await _firestore
        .collection(collectionName)
        .doc(locationId)
        .set(locationData, SetOptions(merge: true));
  }

  /// Uploads multiple locations to Firebase
  /// Requires authentication
  Future<void> uploadLocations(List<Map<String, dynamic>> locations) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Authentication required to upload locations');
    }

    final batch = _firestore.batch();
    
    for (final location in locations) {
      final locationId = location['id'] as String;
      if (locationId.isEmpty) {
        continue; // Skip locations without IDs
      }
      
      final docRef = _firestore.collection(collectionName).doc(locationId);
      batch.set(docRef, location, SetOptions(merge: true));
    }
    
    await batch.commit();
  }

  /// Fetches all locations from Firebase
  Future<List<Map<String, dynamic>>> getAllLocations() async {
    final snapshot = await _firestore.collection(collectionName).get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      // Ensure the document ID is in the data
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Gets a stream of all locations (real-time updates)
  Stream<List<Map<String, dynamic>>> getLocationsStream() {
    return _firestore
        .collection(collectionName)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        // Ensure the document ID is in the data
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Fetches a single location by ID
  Future<Map<String, dynamic>?> getLocationById(String locationId) async {
    final doc = await _firestore
        .collection(collectionName)
        .doc(locationId)
        .get();
    
    if (!doc.exists) {
      return null;
    }
    
    final data = doc.data()!;
    data['id'] = doc.id;
    return data;
  }
}
