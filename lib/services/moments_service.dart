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
  Stream<List<MomentModel>> getInvitedMomentsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(collectionName)
        .where('invitedFriends', arrayContains: user.uid)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MomentModel.fromFirestore(doc.data(), doc.id))
          .toList();
    });
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
    await _firestore
        .collection(collectionName)
        .doc(momentId)
        .update({
      'invitedFriends': FieldValue.arrayUnion(friendIds),
    });

    debugPrint('MomentsService: Invited ${friendIds.length} friends to moment $momentId');
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
