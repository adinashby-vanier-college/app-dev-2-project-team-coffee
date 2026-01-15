import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String? locationId; // Optional: ID of the shared location
  final String? momentId; // Optional: ID of the shared moment
  final String text;
  final DateTime timestamp;
  final bool read;
  final DateTime? readAt;

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.read = false,
    this.readAt,
    this.locationId,
    this.momentId,
  });

  factory Message.fromFirestore(Map<String, dynamic> data, String id) {
    return Message(
      id: id,
      senderId: data['senderId'] as String,
      text: data['text'] as String,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      read: data['read'] as bool? ?? false,
      readAt: data['readAt'] != null
          ? (data['readAt'] as Timestamp).toDate()
          : null,
      locationId: data['locationId'] as String?,
      momentId: data['momentId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'read': read,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      if (locationId != null) 'locationId': locationId,
      if (momentId != null) 'momentId': momentId,
    };
  }
}
