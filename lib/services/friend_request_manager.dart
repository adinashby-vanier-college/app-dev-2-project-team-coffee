import 'dart:async';
import 'package:flutter/foundation.dart';
import 'friends_service.dart';
import 'notification_service.dart';

class FriendRequestManager extends ChangeNotifier {
  final FriendsService _friendsService;
  final NotificationService _notificationService;
  StreamSubscription<List<FriendRequest>>? _subscription;
  Set<String> _knownRequestIds = {};
  bool _isFirstLoad = true;

  FriendRequestManager(this._friendsService, this._notificationService) {
    _init();
  }

  void _init() {
    print('FriendRequestManager: Initializing listener...');
    _subscription = _friendsService.getPendingFriendRequests().listen((requests) {
      print('FriendRequestManager: Received ${requests.length} pending requests');
      if (_isFirstLoad) {
        print('FriendRequestManager: First load, syncing without notify');
        _knownRequestIds = requests.map((r) => r.id).toSet();
        _isFirstLoad = false;
        return;
      }

      for (var request in requests) {
        if (!_knownRequestIds.contains(request.id)) {
          print('FriendRequestManager: NEW REQUEST FOUND! ID: ${request.id}');
          _notificationService.showNotification(
            'New Friend Request',
            'You have a new friend request!',
          );
          _knownRequestIds.add(request.id);
        }
      }
      
      final currentIds = requests.map((r) => r.id).toSet();
      _knownRequestIds = currentIds;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
