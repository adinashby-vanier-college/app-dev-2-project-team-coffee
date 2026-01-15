import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // 'friend_request', 'message', 'moment_invite', etc.
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data; // Additional data like senderId, momentId, etc.

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.data,
  });

  factory NotificationModel.fromFirestore(Map<String, dynamic> doc, String id) {
    return NotificationModel(
      id: id,
      title: doc['title'] as String? ?? '',
      body: doc['body'] as String? ?? '',
      type: doc['type'] as String? ?? 'general',
      createdAt: (doc['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: doc['isRead'] as bool? ?? false,
      data: doc['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'data': data,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }
}
