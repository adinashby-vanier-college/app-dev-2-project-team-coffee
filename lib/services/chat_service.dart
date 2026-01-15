import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Creates or gets an existing conversation between two users
  Future<String> getOrCreateConversation(String otherUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    // Check if conversation already exists
    final existingConversations = await _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUser.uid)
        .get();

    for (var doc in existingConversations.docs) {
      final conversation = Conversation.fromFirestore(doc.data(), doc.id);
      if (conversation.participants.contains(otherUserId) &&
          conversation.participants.length == 2) {
        return doc.id;
      }
    }

    // Create new conversation
    final now = DateTime.now();
    final conversationRef = await _firestore.collection('conversations').add({
      'participants': [currentUser.uid, otherUserId],
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    return conversationRef.id;
  }

  /// Sends a message in a conversation (text or location)
  Future<void> sendMessage(String conversationId, {String? text, String? locationId}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    if ((text == null || text.trim().isEmpty) && locationId == null) {
      throw Exception('Message must have text or location');
    }

    final messageText = text ?? (locationId != null ? 'Shared a location' : '');

    final now = DateTime.now();
    final messageRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc();

    // Use batch write to update conversation and create message atomically
    final batch = _firestore.batch();

    // Create message
    final messageData = {
      'senderId': currentUser.uid,
      'text': messageText,
      'timestamp': Timestamp.fromDate(now),
      'read': false,
    };
    
    if (locationId != null) {
      messageData['locationId'] = locationId;
    }

    batch.set(messageRef, messageData);

    // Update conversation metadata
    batch.update(_firestore.collection('conversations').doc(conversationId), {
      'lastMessage': messageText,
      'lastMessageTime': Timestamp.fromDate(now),
      'lastMessageSenderId': currentUser.uid,
      'updatedAt': Timestamp.fromDate(now),
    });

    await batch.commit();
  }

  /// Gets all conversations for the current user
  Stream<List<Conversation>> getConversations() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Conversation.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  /// Gets all messages for a conversation
  Stream<List<Message>> getMessages(String conversationId) {
    debugPrint('ChatService: Fetching messages for $conversationId');
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        // Removing orderBy to avoid index issues. Sorting client-side.
        // .orderBy('timestamp', descending: false) 
        .snapshots()
        .map((snapshot) {
      debugPrint('ChatService: Found ${snapshot.docs.length} messages for $conversationId');
      final messages = snapshot.docs
          .map((doc) {
            try {
              return Message.fromFirestore(doc.data(), doc.id);
            } catch (e) {
              debugPrint('ChatService: Error parsing message ${doc.id}: $e');
              return null;
            }
          })
          .whereType<Message>() // Filter out nulls
          .toList();
      
      // Sort in memory
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      return messages;
    });
  }

  /// Marks messages as read
  Future<void> markMessagesAsRead(String conversationId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final unreadMessages = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUser.uid)
        .where('read', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    final now = DateTime.now();

    for (var doc in unreadMessages.docs) {
      batch.update(doc.reference, {
        'read': true,
        'readAt': Timestamp.fromDate(now),
      });
    }

    if (unreadMessages.docs.isNotEmpty) {
      await batch.commit();
    }
  }
}
