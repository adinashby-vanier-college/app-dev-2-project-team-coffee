import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Model for location markers
class MapLocation {
  final int id;
  final double xPercent; // Position as percentage (0.0 to 1.0)
  final double yPercent;
  final String name;
  final String type;

  const MapLocation({
    required this.id,
    required this.xPercent,
    required this.yPercent,
    required this.name,
    required this.type,
  });
}

/// CSS-based placeholder map widget
/// This will be replaced with Google Maps SDK integration later
class CssMapWidget extends StatefulWidget {
  const CssMapWidget({super.key});

  @override
  State<CssMapWidget> createState() => _CssMapWidgetState();
}

class _CssMapWidgetState extends State<CssMapWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // Dummy data for places/markers
  final List<MapLocation> locations = const [
    MapLocation(
      id: 1,
      xPercent: 0.40,
      yPercent: 0.35,
      name: 'Central Park',
      type: 'park',
    ),
    MapLocation(
      id: 2,
      xPercent: 0.65,
      yPercent: 0.50,
      name: 'The Local Spot',
      type: 'restaurant',
    ),
    MapLocation(
      id: 3,
      xPercent: 0.25,
      yPercent: 0.70,
      name: 'Home',
      type: 'home',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // THE "FAKE" CSS MAP LAYER (FULL SCREEN)
        _buildMapBackground(context),
        
        // Map Markers
        ...locations.map((loc) => _buildMarker(context, loc)),
        
        // Mock Home Indicator (minimalist touch)
        _buildHomeIndicator(context),
      ],
    );
  }

  Widget _buildMapBackground(BuildContext context) {
    return Container(
      color: const Color(0xFFe5e3df), // bg-[#e5e3df]
      child: Stack(
        children: [
          // Grid pattern to simulate map tiles
          CustomPaint(
            painter: _GridPainter(),
            size: Size.infinite,
          ),
          // Fake Roads
          Positioned(
            top: MediaQuery.of(context).size.height * 0.5 - 20,
            left: 0,
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: MediaQuery.of(context).size.width * (1 / 3) - 24,
            child: Container(
              width: 48,
              height: MediaQuery.of(context).size.height,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.25 - 16,
            left: 0,
            child: Transform.rotate(
              angle: 12 * math.pi / 180,
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.25 - 24,
            left: 0,
            child: Transform.rotate(
              angle: -6 * math.pi / 180,
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: MediaQuery.of(context).size.width * 0.25 - 16,
            child: Container(
              width: 32,
              height: MediaQuery.of(context).size.height,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          // Fake Park Areas
          Positioned(
            top: MediaQuery.of(context).size.height * 0.15,
            left: MediaQuery.of(context).size.width * 0.10,
            child: Transform.rotate(
              angle: 15 * math.pi / 180,
              child: Container(
                width: 192,
                height: 256,
                decoration: BoxDecoration(
                  color: const Color(0xFFc8e6c9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFa5d6a7)),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.10,
            right: MediaQuery.of(context).size.width * 0.05,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: const Color(0xFFc8e6c9).withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarker(BuildContext context, MapLocation location) {
    return Positioned(
      left: MediaQuery.of(context).size.width * location.xPercent - 16,
      top: MediaQuery.of(context).size.height * location.yPercent - 16,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final offset = _animationController.value * -6.0;
          return Transform.translate(
            offset: Offset(0, offset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.red.shade500,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.circle,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.shade100,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    location.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1e293b),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeIndicator(BuildContext context) {
    return Positioned(
      bottom: 8,
      left: MediaQuery.of(context).size.width * 0.5 - 64,
      child: Container(
        width: 128,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.1),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Custom painter for grid pattern
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF919191).withOpacity(0.2)
      ..style = PaintingStyle.fill;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}