import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/location_awareness_service.dart';
import '../services/user_profile_service.dart';

class LocationTrackingProvider with ChangeNotifier {
  static const String _locationKey = 'current_location';
  static const String _isTrackingKey = 'is_location_tracking_enabled';
  final UserProfileService _userProfileService = UserProfileService();

  Map<String, dynamic>? _currentLocation;
  bool _isTrackingEnabled = false;
  bool _isLoadingLocation = false;
  String? _locationError;
  bool _isInitialized = false;

  Map<String, dynamic>? get currentLocation => _currentLocation;
  bool get isTrackingEnabled => _isTrackingEnabled;
  bool get isLoadingLocation => _isLoadingLocation;
  String? get locationError => _locationError;
  bool get isInitialized => _isInitialized;

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
      if (locationJson != null && locationJson.isNotEmpty) {
        try {
          final decoded = json.decode(locationJson);
          if (decoded is Map) {
            _currentLocation = Map<String, dynamic>.from(decoded);
          }
        } catch (e) {
          debugPrint('Error decoding location JSON: $e');
          // If location data is corrupted, clear it
          _currentLocation = null;
          // If toggle was enabled but location is corrupted, disable toggle
          if (_isTrackingEnabled) {
            _isTrackingEnabled = false;
            await _saveTrackingState(false);
          }
        }
      } else {
        // If toggle is enabled but no location data exists, disable toggle
        if (_isTrackingEnabled) {
          _isTrackingEnabled = false;
          await _saveTrackingState(false);
        }
      }
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading persisted location state: $e');
      // On error, reset to safe state
      _isTrackingEnabled = false;
      _currentLocation = null;
      _isInitialized = true;
      notifyListeners();
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

  /// Ensure state consistency - if toggle is enabled but location is missing, disable toggle
  Future<void> _ensureStateConsistency() async {
    if (_isTrackingEnabled && _currentLocation == null) {
      debugPrint('State inconsistency detected: toggle enabled but no location. Disabling toggle.');
      _isTrackingEnabled = false;
      await _saveTrackingState(false);
      notifyListeners();
    }
  }

  /// Toggle location tracking on/off
  Future<void> toggleLocationTracking() async {
    // Ensure state is consistent before toggling
    await _ensureStateConsistency();
    
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
      await _userProfileService.updateUserLocation(locationData);
      
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
      await _userProfileService.updateUserLocation(locationData);
      
      notifyListeners();
    } catch (e) {
      _locationError = e.toString();
      _isLoadingLocation = false;
      
      notifyListeners();
      rethrow;
    }
  }
}
