import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Shows a local notification AND stores it in Firestore for history
  Future<void> showNotification(
    String title, 
    String body, {
    String type = 'general',
    Map<String, dynamic>? data,
  }) async {
    // Show local notification
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'friend_requests_channel',
      'Friend Requests',
      channelDescription: 'Notifications for new friend requests',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: DarwinNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
    );

    // Store in Firestore for history
    await storeNotification(title, body, type: type, data: data);
  }

  /// Stores a notification in Firestore
  Future<void> storeNotification(
    String title,
    String body, {
    String type = 'general',
    Map<String, dynamic>? data,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('NotificationService: Cannot store notification - no user');
      return;
    }

    debugPrint('NotificationService: Storing notification - title: $title, type: $type, user: ${user.uid}');

    final notification = NotificationModel(
      id: '', // Will be set by Firestore
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
      isRead: false,
      data: data,
    );

    try {
      final docRef = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .add(notification.toFirestore());
      debugPrint('NotificationService: Successfully stored notification with id: ${docRef.id}');
    } catch (e) {
      debugPrint('NotificationService: Error storing notification: $e');
      rethrow;
    }
  }

  /// Gets all notifications for the current user
  Stream<List<NotificationModel>> getNotificationsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('NotificationService: getNotificationsStream - no user');
      return Stream.value([]);
    }

    debugPrint('NotificationService: Setting up notifications stream for user ${user.uid}');
    
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      final notifications = snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc.data(), doc.id))
          .toList();
      debugPrint('NotificationService: Stream emitted ${notifications.length} notifications');
      return notifications;
    });
  }

  /// Gets unread notification count
  Stream<int> getUnreadCountStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Marks a notification as read
  Future<void> markAsRead(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  /// Marks all notifications as read
  Future<void> markAllAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  /// Deletes a notification
  Future<void> deleteNotification(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  /// Deletes all notifications for the current user
  Future<void> deleteAllNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .get();

    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}

