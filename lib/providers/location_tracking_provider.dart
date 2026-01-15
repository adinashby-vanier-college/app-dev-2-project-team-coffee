import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/location_awareness_service.dart';

class LocationTrackingProvider with ChangeNotifier {
  static const String _locationKey = 'current_location';
  static const String _isTrackingKey = 'is_location_tracking_enabled';

  Map<String, dynamic>? _currentLocation;
  bool _isTrackingEnabled = false;
  bool _isLoadingLocation = false;
  String? _locationError;

  Map<String, dynamic>? get currentLocation => _currentLocation;
  bool get isTrackingEnabled => _isTrackingEnabled;
  bool get isLoadingLocation => _isLoadingLocation;
  String? get locationError => _locationError;

  LocationTrackingProvider() {
    _loadPersistedState();
  }

  /// Load persisted state from SharedPreferences
  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load tracking enabled state
      _isTrackingEnabled = prefs.getBool(_isTrackingKey) ?? false;
      
      // Load location data if it exists
      final locationJson = prefs.getString(_locationKey);
      if (locationJson != null) {
        _currentLocation = Map<String, dynamic>.from(json.decode(locationJson));
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading persisted location state: $e');
    }
  }

  /// Save location to SharedPreferences
  Future<void> _saveLocation(Map<String, dynamic> location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_locationKey, json.encode(location));
    } catch (e) {
      debugPrint('Error saving location: $e');
    }
  }

  /// Save tracking enabled state to SharedPreferences
  Future<void> _saveTrackingState(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isTrackingKey, enabled);
    } catch (e) {
      debugPrint('Error saving tracking state: $e');
    }
  }

  /// Clear location from SharedPreferences
  Future<void> _clearLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_locationKey);
    } catch (e) {
      debugPrint('Error clearing location: $e');
    }
  }

  /// Toggle location tracking on/off
  Future<void> toggleLocationTracking() async {
    if (_isTrackingEnabled) {
      // Turn off tracking
      await turnOffLocationTracking();
    } else {
      // Turn on tracking and fetch location
      await turnOnLocationTracking();
    }
  }

  /// Turn on location tracking and fetch current location
  Future<void> turnOnLocationTracking() async {
    if (_isLoadingLocation) return;

    _isLoadingLocation = true;
    _locationError = null;
    notifyListeners();

    try {
      final locationService = LocationAwarenessService.instance;
      final locationData = await locationService.getUserLocationWithAddress();
      
      _currentLocation = locationData;
      _isTrackingEnabled = true;
      _isLoadingLocation = false;
      
      // Persist the location and tracking state
      await _saveLocation(locationData);
      await _saveTrackingState(true);
      
      notifyListeners();
    } catch (e) {
      _locationError = e.toString();
      _isLoadingLocation = false;
      _currentLocation = null;
      _isTrackingEnabled = false;
      
      await _saveTrackingState(false);
      
      notifyListeners();
      rethrow;
    }
  }

  /// Turn off location tracking and clear location
  Future<void> turnOffLocationTracking() async {
    _isTrackingEnabled = false;
    _currentLocation = null;
    _locationError = null;
    
    // Clear persisted location and update tracking state
    await _clearLocation();
    await _saveTrackingState(false);
    
    notifyListeners();
  }

  /// Refresh the current location (only if tracking is enabled)
  Future<void> refreshLocation() async {
    if (!_isTrackingEnabled || _isLoadingLocation) return;

    _isLoadingLocation = true;
    _locationError = null;
    notifyListeners();

    try {
      final locationService = LocationAwarenessService.instance;
      final locationData = await locationService.getUserLocationWithAddress();
      
      _currentLocation = locationData;
      _isLoadingLocation = false;
      
      // Update persisted location
      await _saveLocation(locationData);
      
      notifyListeners();
    } catch (e) {
      _locationError = e.toString();
      _isLoadingLocation = false;
      
      notifyListeners();
      rethrow;
    }
  }
}
