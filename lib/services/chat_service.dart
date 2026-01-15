import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  /// Sends a message in a conversation
  Future<void> sendMessage(String conversationId, String text) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    final now = DateTime.now();
    final messageRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc();

    // Use batch write to update conversation and create message atomically
    final batch = _firestore.batch();

    // Create message
    batch.set(messageRef, {
      'senderId': currentUser.uid,
      'text': text,
      'timestamp': Timestamp.fromDate(now),
      'read': false,
    });

    // Update conversation metadata
    batch.update(_firestore.collection('conversations').doc(conversationId), {
      'lastMessage': text,
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
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Message.fromFirestore(doc.data(), doc.id))
          .toList();
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
