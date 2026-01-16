import 'package:flutter/material.dart';

class NavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isFloating;
  final bool isOnDarkBackground;
  final Color? activeColorOverride;
  final Color? inactiveColorOverride;

  const NavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isFloating = false,
    this.isOnDarkBackground = false,
    this.activeColorOverride,
    this.inactiveColorOverride,
  });

  @override
  Widget build(BuildContext context) {
    final inactiveColor = inactiveColorOverride ??
        (isOnDarkBackground
            ? const Color(0xFFEDEDED)
            : const Color(0xFF111111));
    final activeColor = activeColorOverride ?? const Color(0xFF00B030);

    final navItems = const [
      _NavItemData(id: 0, icon: Icons.home_rounded, label: 'Home'),
      _NavItemData(id: 1, icon: Icons.group_rounded, label: 'Friends'),
      _NavItemData(id: 2, icon: Icons.calendar_month_rounded, label: 'Moments'),
      _NavItemData(id: 3, icon: Icons.chat_bubble_rounded, label: 'Chat'),
    ];

    final navRow = SizedBox(
      width: 320,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: navItems.map((item) {
          final isActive = currentIndex == item.id;
          return _NavBarItem(
            icon: item.icon,
            label: item.label,
            isActive: isActive,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            onTap: () => onTap(item.id),
          );
        }).toList(),
      ),
    );

    final bottomPadding = 8.0;
    final navHeight = kBottomNavigationBarHeight + bottomPadding;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: navHeight,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: navRow,
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final int id;
  final IconData icon;
  final String label;

  const _NavItemData({
    required this.id,
    required this.icon,
    required this.label,
  });
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: isActive ? 1.1 : 1.0,
              child: Icon(
                icon,
                size: 24,
                color: isActive ? activeColor : inactiveColor,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                  if (isActive)
                    const Shadow(
                      color: Color(0x8000B030),
                      blurRadius: 8,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
