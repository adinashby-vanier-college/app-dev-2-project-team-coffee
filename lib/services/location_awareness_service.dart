import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../utils/distance_utils.dart';

/// Service for location awareness without Google Maps SDK
/// Provides GPS location, reverse geocoding, and nearby logic
class LocationAwarenessService {
  static final LocationAwarenessService instance = LocationAwarenessService._();

  LocationAwarenessService._();

  /// Get user's current GPS position
  /// Throws exception if location services disabled or permission denied
  Future<Position> getUserPosition() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services are disabled. Please enable location services.");
    }

    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied. Please grant location permission.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permission permanently denied. Please enable it in app settings.");
    }

    // Get current position with high accuracy
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Reverse geocoding: Convert lat/lng to human-readable address
  /// Returns formatted address string
  Future<String> getAddress(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) {
        return 'Address not available';
      }

      Placemark p = placemarks.first;
      // Build address string
      final parts = <String>[];
      if (p.street != null && p.street!.isNotEmpty) parts.add(p.street!);
      if (p.locality != null && p.locality!.isNotEmpty) parts.add(p.locality!);
      if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
        parts.add(p.administrativeArea!);
      }
      if (p.country != null && p.country!.isNotEmpty) parts.add(p.country!);

      return parts.isEmpty ? 'Address not available' : parts.join(', ');
    } catch (e) {
      return 'Address lookup failed: $e';
    }
  }

  /// Get user position with address
  /// Returns a map with position and address
  Future<Map<String, dynamic>> getUserLocationWithAddress() async {
    final position = await getUserPosition();
    final address = await getAddress(position.latitude, position.longitude);

    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'address': address,
      'accuracy': position.accuracy,
      'timestamp': position.timestamp,
    };
  }

  /// Find nearby places from a list of locations
  /// [userLat] and [userLng] are the user's coordinates
  /// [places] is a list of maps with 'latitude' and 'longitude' keys
  /// [radiusMeters] is the search radius (default 1000m = 1km)
  /// Returns list of places within radius, sorted by distance
  List<Map<String, dynamic>> findNearbyPlaces({
    required double userLat,
    required double userLng,
    required List<Map<String, dynamic>> places,
    double radiusMeters = 1000,
  }) {
    final nearbyPlaces = <Map<String, dynamic>>[];

    for (var place in places) {
      final placeLat = place['latitude'] as double?;
      final placeLng = place['longitude'] as double?;

      if (placeLat == null || placeLng == null) continue;

      final distance = DistanceUtils.calculateDistance(
        userLat,
        userLng,
        placeLat,
        placeLng,
      );

      if (distance <= radiusMeters) {
        nearbyPlaces.add({
          ...place,
          'distance': distance,
          'distanceFormatted': DistanceUtils.formatDistance(distance),
        });
      }
    }

    // Sort by distance (closest first)
    nearbyPlaces.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

    return nearbyPlaces;
  }

  /// Check if a specific location is within radius
  bool isLocationNearby({
    required double userLat,
    required double userLng,
    required double targetLat,
    required double targetLng,
    required double radiusMeters,
  }) {
    return DistanceUtils.isWithinRadius(
      userLat,
      userLng,
      targetLat,
      targetLng,
      radiusMeters,
    );
  }
}
