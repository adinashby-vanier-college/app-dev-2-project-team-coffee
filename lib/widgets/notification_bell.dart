import 'package:flutter/material.dart';
import '../pages/notifications_page.dart';
import '../services/notification_service.dart';

class NotificationBell extends StatelessWidget {
  final bool isOnDarkBackground;
  final Color? iconColor;
  final Color? badgeColor;

  const NotificationBell({
    super.key,
    this.isOnDarkBackground = false,
    this.iconColor,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final notificationService = NotificationService();

    return StreamBuilder<int>(
      stream: notificationService.getUnreadCountStream(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        final resolvedIconColor = iconColor ??
            (isOnDarkBackground ? const Color(0xFFEDEDED) : const Color(0xFF111111));

        final resolvedBadgeColor = badgeColor ?? const Color(0xFF00B030);

        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                icon: Icon(
                  Icons.notifications_outlined,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                iconSize: 26,
                color: resolvedIconColor,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const NotificationsPage(),
                    ),
                  );
                },
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: TextStyle(
                    color: resolvedBadgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: resolvedBadgeColor.withOpacity(0.8),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
