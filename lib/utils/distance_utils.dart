import 'dart:math';

/// Utility class for calculating distances between geographic coordinates
/// using the Haversine formula (no Google Maps SDK required)
class DistanceUtils {
  /// Earth's radius in meters
  static const double earthRadiusMeters = 6371000;

  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in meters
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * asin(sqrt(a));

    return earthRadiusMeters * c;
  }

  /// Convert degrees to radians
  static double _toRadians(double degrees) {
    return degrees * (3.141592653589793 / 180.0);
  }

  /// Check if a location is within a specified radius (in meters)
  static bool isWithinRadius(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
    double radiusMeters,
  ) {
    return calculateDistance(lat1, lon1, lat2, lon2) <= radiusMeters;
  }

  /// Format distance in a human-readable format
  static String formatDistance(double distanceMeters) {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()}m';
    } else {
      return '${(distanceMeters / 1000).toStringAsFixed(1)}km';
    }
  }
}
