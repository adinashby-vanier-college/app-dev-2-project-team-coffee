import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../services/user_profile_service.dart';
import '../pages/landing_page.dart';
import '../pages/profile_page.dart';
import '../pages/settings_page.dart';

class _MenuItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDanger;
  final bool isOnDarkBackground;

  const _MenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDanger = false,
    this.isOnDarkBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isDanger
        ? (isOnDarkBackground ? Colors.red.shade300 : Colors.red.shade600)
        : (isOnDarkBackground
            ? const Color(0xFFEDEDED)
            : const Color(0xFF111111));
    final hoverColor = isDanger
        ? (isOnDarkBackground
            ? Colors.redAccent.withOpacity(0.08)
            : Colors.redAccent.withOpacity(0.08))
        : (isOnDarkBackground
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.05));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: hoverColor,
        splashColor: hoverColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: baseColor.withOpacity(0.8)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: baseColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserMenuWidget extends StatefulWidget {
  final bool isOnDarkBackground;
  final Color? iconColorOverride;
  final Color? borderColorOverride;

  const UserMenuWidget({
    super.key,
    this.isOnDarkBackground = false,
    this.iconColorOverride,
    this.borderColorOverride,
  });

  @override
  State<UserMenuWidget> createState() => _UserMenuWidgetState();
}

class _UserMenuWidgetState extends State<UserMenuWidget> {
  bool _isOpen = false;
  bool _isPressed = false;
  OverlayEntry? _overlayEntry;
  UserModel? _userProfile;
  late final UserProfileService _userProfileService;

  @override
  void initState() {
    super.initState();
    _userProfileService = UserProfileService();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _userProfileService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    } catch (_) {
      // Fail silently; fallback UI will be used.
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _handleProfile() {
    _closeMenu();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ProfilePage()),
    );
  }

  void _handleSettings() {
    _closeMenu();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  Future<void> _handleLogout() async {
    _closeMenu();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProfileService = UserProfileService();

    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) {
      return;
    }

    try {
      // Validate/ensure user document exists in Firestore before logout
      // This helps fix the issue where users don't appear in each other's requests
      await userProfileService.ensureUserDocumentExists();

      // Sign out after validation
      await authProvider.signOut();

      // Navigate to landing page after logout
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LandingPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during logout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleMenu() {
    if (_isOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    setState(() {
      _isOpen = true;
    });
    _showOverlay();
  }

  void _closeMenu() {
    setState(() {
      _isOpen = false;
    });
    _removeOverlay();
  }

  void _showOverlay() {
    final overlay = Overlay.of(context);
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        top: 0,
        right: 0,
        bottom: 0,
        child: GestureDetector(
          onTap: _closeMenu,
          child: Container(
            color: Colors.transparent,
            child: Stack(
              children: [
                Positioned(
                  right: MediaQuery.of(context).size.width - offset.dx - size.width,
                  top: offset.dy + size.height + 8,
                  child: GestureDetector(
                    onTap: () {}, // Prevent closing when clicking inside menu
                    child: _buildMenu(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  Widget _buildMenu() {
    final isOnDark = widget.isOnDarkBackground;
    final backgroundColor = Colors.white;
    final borderColor = Colors.black.withOpacity(0.08);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 100),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (value * 0.05),
          alignment: Alignment.topRight,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MenuItem(
                  label: 'Profile',
                  icon: Icons.person,
                  onTap: _handleProfile,
                isOnDarkBackground: false,
                ),
                _MenuItem(
                  label: 'Settings',
                  icon: Icons.settings,
                  onTap: _handleSettings,
                isOnDarkBackground: false,
                ),
                Divider(
                  height: 1,
                color: Colors.black.withOpacity(0.08),
                ),
                _MenuItem(
                  label: 'Logout',
                  icon: Icons.logout,
                  onTap: _handleLogout,
                  isDanger: true,
                isOnDarkBackground: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.iconColorOverride ??
        (widget.isOnDarkBackground
            ? const Color(0xFFEDEDED)
            : const Color(0xFF111111));
    final borderColor = widget.borderColorOverride ??
        (widget.isOnDarkBackground
            ? Colors.white.withOpacity(0.2)
            : Colors.black.withOpacity(0.15));

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapCancel: () => setState(() => _isPressed = false),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTap: _toggleMenu,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: _isPressed ? 0.96 : (_isOpen ? 1.05 : 1.0),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: ClipOval(
              child: SizedBox(
                width: 32,
                height: 32,
                child: _userProfile != null &&
                        _userProfile!.photoURL != null &&
                        _userProfile!.photoURL!.isNotEmpty
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: _userProfile!.photoURL!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.person,
                            size: 20,
                            color: Color(0xFF00B030),
                          ),
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 26,
                        color: const Color(0xFF00B030),
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


