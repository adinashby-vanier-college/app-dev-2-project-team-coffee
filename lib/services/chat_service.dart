import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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
      debugPrint('ChatService.getOrCreateConversation: No authenticated user');
      throw Exception('No authenticated user');
    }

    debugPrint('ChatService.getOrCreateConversation: Looking for conversation between ${currentUser.uid} and $otherUserId');

    // Check if conversation already exists
    try {
      final existingConversations = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      debugPrint('ChatService.getOrCreateConversation: Found ${existingConversations.docs.length} conversations with current user');

      for (var doc in existingConversations.docs) {
        final conversation = Conversation.fromFirestore(doc.data(), doc.id);
        debugPrint('ChatService.getOrCreateConversation: Checking conversation ${doc.id} with participants: ${conversation.participants}');
        if (conversation.participants.contains(otherUserId) &&
            conversation.participants.length == 2) {
          debugPrint('ChatService.getOrCreateConversation: Found existing conversation: ${doc.id}');
          return doc.id;
        }
      }

      // Create new conversation
      debugPrint('ChatService.getOrCreateConversation: Creating new conversation');
      final now = DateTime.now();
      final conversationData = {
        'participants': [currentUser.uid, otherUserId],
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };
      
      debugPrint('ChatService.getOrCreateConversation: Conversation data: $conversationData');
      
      try {
        final conversationRef = await _firestore.collection('conversations').add(conversationData);
        debugPrint('ChatService.getOrCreateConversation: ✅✅✅ Created new conversation: ${conversationRef.id}');
        debugPrint('ChatService.getOrCreateConversation: Conversation path: ${conversationRef.path}');
        
        // Verify the conversation was actually created
        final verifyDoc = await conversationRef.get();
        if (verifyDoc.exists) {
          debugPrint('ChatService.getOrCreateConversation: ✅ Verified: Conversation document exists in Firestore');
          debugPrint('ChatService.getOrCreateConversation: Conversation data: ${verifyDoc.data()}');
        } else {
          debugPrint('ChatService.getOrCreateConversation: ⚠️ WARNING: Conversation document does NOT exist after creation!');
        }
        
        return conversationRef.id;
      } catch (e, stackTrace) {
        debugPrint('ChatService.getOrCreateConversation: ❌❌❌ ERROR creating conversation: $e');
        debugPrint('ChatService.getOrCreateConversation: Error type: ${e.runtimeType}');
        debugPrint('ChatService.getOrCreateConversation: Stack trace: $stackTrace');
        
        if (e is FirebaseException) {
          debugPrint('ChatService.getOrCreateConversation: Firebase error code: ${e.code}');
          debugPrint('ChatService.getOrCreateConversation: Firebase error message: ${e.message}');
          
          if (e.code == 'permission-denied') {
            debugPrint('ChatService.getOrCreateConversation: ⚠️ PERMISSION DENIED - Check Firestore rules!');
            debugPrint('ChatService.getOrCreateConversation: Current user: ${currentUser.uid}');
          }
        }
        
        rethrow;
      }
    } catch (e) {
      debugPrint('ChatService.getOrCreateConversation: Error: $e');
      debugPrint('ChatService.getOrCreateConversation: Error details: ${e.toString()}');
      rethrow;
    }
  }

  /// Sends a message in a conversation (text, location, or moment)
  Future<void> sendMessage(String conversationId, {String? text, String? locationId, String? momentId}) async {
    debugPrint('🟢 ChatService.sendMessage: CALLED with conversationId=$conversationId, text=$text, locationId=$locationId, momentId=$momentId');
    
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('❌ ChatService.sendMessage: No authenticated user');
      throw Exception('No authenticated user');
    }
    
    debugPrint('🟢 ChatService.sendMessage: User authenticated: ${currentUser.uid}');

    if ((text == null || text.trim().isEmpty) && locationId == null && momentId == null) {
      debugPrint('ChatService.sendMessage: Message must have text, location, or moment');
      throw Exception('Message must have text, location, or moment');
    }

    final messageText = text ?? (locationId != null ? 'Shared a location' : momentId != null ? 'Shared a moment' : '');

    debugPrint('ChatService.sendMessage: Sending message to conversation $conversationId');
    debugPrint('ChatService.sendMessage: Message text: $messageText, locationId: $locationId, momentId: $momentId');
    debugPrint('ChatService.sendMessage: Sender: ${currentUser.uid}');

    // Verify conversation exists and user is a participant
    try {
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();
      
      if (!conversationDoc.exists) {
        debugPrint('ChatService.sendMessage: Conversation $conversationId does not exist');
        throw Exception('Conversation does not exist');
      }

      final conversationData = conversationDoc.data();
      if (conversationData == null) {
        debugPrint('ChatService.sendMessage: Conversation $conversationId has no data');
        throw Exception('Conversation has no data');
      }

      final participants = List<String>.from(conversationData['participants'] ?? []);
      if (!participants.contains(currentUser.uid)) {
        debugPrint('ChatService.sendMessage: User ${currentUser.uid} is not a participant in conversation $conversationId');
        debugPrint('ChatService.sendMessage: Participants: $participants');
        throw Exception('User is not a participant in this conversation');
      }

      debugPrint('ChatService.sendMessage: Conversation verified, participants: $participants');
    } catch (e) {
      debugPrint('ChatService.sendMessage: Error verifying conversation: $e');
      rethrow;
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
    final messageData = {
      'senderId': currentUser.uid,
      'text': messageText,
      'timestamp': Timestamp.fromDate(now),
      'read': false,
    };
    
    if (locationId != null) {
      messageData['locationId'] = locationId;
    }
    
    if (momentId != null) {
      messageData['momentId'] = momentId;
    }

    debugPrint('ChatService.sendMessage: Message data: $messageData');
    debugPrint('ChatService.sendMessage: Message reference path: ${messageRef.path}');

    batch.set(messageRef, messageData);

    // Update conversation metadata - use update to preserve existing fields like participants
    final conversationRef = _firestore.collection('conversations').doc(conversationId);
    batch.update(conversationRef, {
      'lastMessage': messageText,
      'lastMessageTime': Timestamp.fromDate(now),
      'lastMessageSenderId': currentUser.uid,
      'updatedAt': Timestamp.fromDate(now),
    });
    debugPrint('ChatService.sendMessage: Conversation update added to batch');

    debugPrint('ChatService.sendMessage: Batch prepared, committing...');
    debugPrint('ChatService.sendMessage: Conversation reference path: ${conversationRef.path}');
    debugPrint('ChatService.sendMessage: Batch contains 2 operations: 1 message write + 1 conversation update');
    
    try {
      debugPrint('ChatService.sendMessage: Calling batch.commit()...');
      await batch.commit();
      debugPrint('ChatService.sendMessage: ✅✅✅ Batch.commit() returned successfully!');
      debugPrint('ChatService.sendMessage: Message ID: ${messageRef.id}');
      debugPrint('ChatService.sendMessage: Message path: ${messageRef.path}');
      
      // Wait a moment for Firestore to propagate
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Verify the message was actually written by reading it back
      debugPrint('ChatService.sendMessage: Verifying message was written...');
      final verifyDoc = await messageRef.get();
      if (verifyDoc.exists) {
        debugPrint('ChatService.sendMessage: ✅✅✅ VERIFIED: Message document EXISTS in Firestore!');
        debugPrint('ChatService.sendMessage: Message document data: ${verifyDoc.data()}');
        
        // Also verify conversation was updated
        final verifyConv = await conversationRef.get();
        if (verifyConv.exists) {
          final convData = verifyConv.data();
          debugPrint('ChatService.sendMessage: ✅ Conversation updated - lastMessage: ${convData?['lastMessage']}');
        } else {
          debugPrint('ChatService.sendMessage: ⚠️ WARNING: Conversation document does not exist!');
        }
      } else {
        debugPrint('ChatService.sendMessage: ⚠️⚠️⚠️ CRITICAL: Message document does NOT exist after commit!');
        debugPrint('ChatService.sendMessage: This indicates the batch write failed silently or was rejected by Firestore rules');
      }
    } catch (e, stackTrace) {
      debugPrint('ChatService.sendMessage: ❌❌❌ ERROR committing batch: $e');
      debugPrint('ChatService.sendMessage: Error type: ${e.runtimeType}');
      debugPrint('ChatService.sendMessage: Full error: ${e.toString()}');
      debugPrint('ChatService.sendMessage: Stack trace: $stackTrace');
      
      // Try to get more details if it's a FirebaseException
      if (e is FirebaseException) {
        debugPrint('ChatService.sendMessage: Firebase error code: ${e.code}');
        debugPrint('ChatService.sendMessage: Firebase error message: ${e.message}');
        debugPrint('ChatService.sendMessage: Firebase error plugin: ${e.plugin}');
        
        if (e.code == 'permission-denied') {
          debugPrint('ChatService.sendMessage: ⚠️ PERMISSION DENIED - Check Firestore rules!');
          debugPrint('ChatService.sendMessage: Current user: ${currentUser.uid}');
          debugPrint('ChatService.sendMessage: Conversation ID: $conversationId');
        }
      }
      
      rethrow;
    }
  }

  /// Gets all conversations for the current user
  Stream<List<Conversation>> getConversations() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('ChatService.getConversations: No authenticated user');
      return Stream.value([]);
    }

    debugPrint('ChatService.getConversations: Fetching conversations for user: ${currentUser.uid}');

    Stream<QuerySnapshot<Map<String, dynamic>>> queryStream = _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();

    return queryStream
        .handleError((error) {
          debugPrint('ChatService.getConversations: ❌ Stream error: $error');
          debugPrint('ChatService.getConversations: Error type: ${error.runtimeType}');
          if (error is FirebaseException) {
            debugPrint('ChatService.getConversations: Firebase error code: ${error.code}');
            debugPrint('ChatService.getConversations: Firebase error message: ${error.message}');
            if (error.code == 'failed-precondition') {
              debugPrint('ChatService.getConversations: ⚠️ Index required! Deploy firestore.indexes.json');
            }
          }
        })
        .map((snapshot) {
      debugPrint('ChatService.getConversations: Received snapshot with ${snapshot.docs.length} conversations');
      
      final conversations = snapshot.docs
          .map((doc) {
            try {
              debugPrint('ChatService.getConversations: Parsing conversation ${doc.id}');
              final data = doc.data();
              debugPrint('ChatService.getConversations: Conversation data: $data');
              final conversation = Conversation.fromFirestore(data, doc.id);
              debugPrint('ChatService.getConversations: Successfully parsed conversation ${doc.id} with participants: ${conversation.participants}');
              return conversation;
            } catch (e, stackTrace) {
              debugPrint('ChatService.getConversations: ❌ Error parsing conversation ${doc.id}: $e');
              debugPrint('ChatService.getConversations: Stack trace: $stackTrace');
              debugPrint('ChatService.getConversations: Document data: ${doc.data()}');
              return null;
            }
          })
          .whereType<Conversation>()
          .toList();
      
      debugPrint('ChatService.getConversations: Returning ${conversations.length} conversations');
      
      // Debug: Verify we can find conversations by doing a direct query
      if (conversations.isEmpty) {
        debugPrint('ChatService.getConversations: ⚠️ No conversations found, doing verification query...');
        _firestore
            .collection('conversations')
            .where('participants', arrayContains: currentUser.uid)
            .get()
            .then((verifySnapshot) {
          debugPrint('ChatService.getConversations: Verification query found ${verifySnapshot.docs.length} conversations');
          for (var doc in verifySnapshot.docs) {
            debugPrint('ChatService.getConversations: Found conversation ${doc.id} with data: ${doc.data()}');
          }
        }).catchError((e) {
          debugPrint('ChatService.getConversations: Verification query error: $e');
        });
      }
      
      return conversations;
    });
  }

  /// Gets all messages for a conversation
  Stream<List<Message>> getMessages(String conversationId) {
    debugPrint('ChatService.getMessages: Fetching messages for conversation $conversationId');
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('ChatService.getMessages: No authenticated user');
      return Stream.value([]);
    }

    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        // Removing orderBy to avoid index issues. Sorting client-side.
        // .orderBy('timestamp', descending: false) 
        .snapshots()
        .handleError((error) {
          debugPrint('ChatService.getMessages: Stream error for conversation $conversationId: $error');
          debugPrint('ChatService.getMessages: Error details: ${error.toString()}');
        })
        .map((snapshot) {
      debugPrint('ChatService.getMessages: Received snapshot with ${snapshot.docs.length} messages for conversation $conversationId');

      final messages = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              debugPrint('ChatService.getMessages: Parsing message ${doc.id} with data: $data');
              final message = Message.fromFirestore(data, doc.id);
              debugPrint('ChatService.getMessages: Successfully parsed message ${doc.id}');
              return message;
            } catch (e, stackTrace) {
              debugPrint('ChatService.getMessages: Error parsing message ${doc.id}: $e');
              debugPrint('ChatService.getMessages: Stack trace: $stackTrace');
              debugPrint('ChatService.getMessages: Message data: ${doc.data()}');
              return null;
            }
          })
          .whereType<Message>() // Filter out nulls
          .toList();
      
      debugPrint('ChatService.getMessages: Successfully parsed ${messages.length} messages');
      
      // Sort in memory
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      debugPrint('ChatService.getMessages: Returning ${messages.length} sorted messages');
      return messages;
    });
  }

  /// Marks messages as read
  Future<void> markMessagesAsRead(String conversationId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Get all messages and filter client-side to avoid index requirement
      final allMessages = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .get();
      
      final unreadMessages = allMessages.docs.where((doc) {
        final data = doc.data();
        return data['senderId'] != currentUser.uid && 
               (data['read'] == false || data['read'] == null);
      }).toList();

      final batch = _firestore.batch();
      final now = DateTime.now();

      for (var doc in unreadMessages) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': Timestamp.fromDate(now),
        });
      }

      if (unreadMessages.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('ChatService.markMessagesAsRead: Error: $e');
      // Don't throw - this is a non-critical operation
    }
  }
}
