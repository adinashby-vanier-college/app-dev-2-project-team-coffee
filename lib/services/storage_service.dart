import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  // Explicitly target the Firebase Storage bucket:
  // gs://friendmap-5b654.firebasestorage.app
  final FirebaseStorage _storage =
      FirebaseStorage.instanceFor(bucket: 'friendmap-5b654.firebasestorage.app');
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
      final bucketName = _storage.app.options.storageBucket ?? 'unknown';
      debugPrint('Uploading to bucket: $bucketName');
      
      // Reference to storage location: profile_pictures/{userId}.jpg
      final storageRef = _storage
          .ref()
          .child('profile_pictures')
          .child('${user.uid}.jpg');

      debugPrint('Upload path: profile_pictures/${user.uid}.jpg');

      // Upload file
      final uploadTask = storageRef.putFile(imageFile);
      
      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Get download URL
      final downloadURL = await snapshot.ref.getDownloadURL();
      
      debugPrint('Upload successful! URL: $downloadURL');
      return downloadURL;
    } on FirebaseException catch (e) {
      debugPrint('Firebase Storage error: code=${e.code}, message=${e.message}');
      if (e.code == 'object-not-found' || e.code == 'bucket-not-found') {
        throw Exception(
          'Storage bucket not found. Please ensure Firebase Storage is enabled '
          'in your Firebase Console and the bucket name matches your project ID.'
        );
      }
      throw Exception('Failed to upload image: ${e.message ?? e.code}');
    } catch (e) {
      debugPrint('Upload error: $e');
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
    } on FirebaseException catch (e) {
      // Ignore if file doesn't exist
      if (e.code == 'object-not-found') return;
      debugPrint('Error deleting old picture: $e');
    } catch (e) {
      debugPrint('Error deleting old picture: $e');
    }
  }
}
