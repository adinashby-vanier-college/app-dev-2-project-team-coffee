import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/user_profile_service.dart';
import '../pages/landing_page.dart';

class _LogoutMenuItem extends StatefulWidget {
  final VoidCallback onTap;

  const _LogoutMenuItem({required this.onTap});

  @override
  State<_LogoutMenuItem> createState() => _LogoutMenuItemState();
}

class _LogoutMenuItemState extends State<_LogoutMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          color: _isHovered ? Colors.red.shade50 : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _isHovered
                      ? Colors.red.shade100.withOpacity(0.5)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.logout,
                  size: 15,
                  color: _isHovered ? Colors.red.shade500 : Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Logout',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _isHovered ? Colors.red.shade600 : Colors.black87,
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
  const UserMenuWidget({super.key});

  @override
  State<UserMenuWidget> createState() => _UserMenuWidgetState();
}

class _UserMenuWidgetState extends State<UserMenuWidget> {
  bool _isOpen = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade100,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Material(
            color: Colors.transparent,
            child: _LogoutMenuItem(
              onTap: _handleLogout,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleMenu,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: _isOpen
                ? Colors.grey.shade400
                : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: _isOpen
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                Icons.person,
                size: 18,
                color: Colors.grey.shade600,
              ),
            ),
            // Subtle shine effect
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withOpacity(0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


