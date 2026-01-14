import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  /// Pick an image from gallery or camera
  Future<File?> pickImage({bool fromCamera = false}) async {
    final XFile? image = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85, // Compress to 85% quality
      maxWidth: 1024,   // Resize if larger
      maxHeight: 1024,
    );
    
    if (image == null) return null;
    return File(image.path);
  }

  /// Upload profile picture and return download URL
  Future<String> uploadProfilePicture(File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    try {
      // Reference to storage location: profile_pictures/{userId}.jpg
      final storageRef = _storage
          .ref()
          .child('profile_pictures')
          .child('${user.uid}.jpg');

      // Upload file
      final uploadTask = storageRef.putFile(imageFile);
      
      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Get download URL
      final downloadURL = await snapshot.ref.getDownloadURL();
      
      return downloadURL;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Delete old profile picture (optional cleanup)
  Future<void> deleteProfilePicture() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _storage
          .ref()
          .child('profile_pictures')
          .child('${user.uid}.jpg')
          .delete();
    } catch (e) {
      // Ignore if file doesn't exist
      debugPrint('Error deleting old picture: $e');
    }
  }
}
