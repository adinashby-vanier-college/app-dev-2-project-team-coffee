import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/saved_locations_service.dart';

class SavedLocationsProvider with ChangeNotifier {
  final SavedLocationsService _savedLocationsService = SavedLocationsService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<String> _savedLocationIds = [];
  StreamSubscription<List<String>>? _locationsSubscription;
  StreamSubscription<User?>? _authSubscription;
  bool _isLoading = true;

  List<String> get savedLocationIds => _savedLocationIds;
  bool get isLoading => _isLoading;

  bool isSaved(String locationId) {
    return _savedLocationIds.contains(locationId);
  }

  SavedLocationsProvider() {
    // Listen to auth state changes to reinitialize when user logs in/out
    _authSubscription = _auth.authStateChanges().listen((user) {
      debugPrint('SavedLocationsProvider: Auth state changed, user: ${user?.uid}');
      _initializeForCurrentUser();
    });
    
    // Also try to initialize immediately if user is already logged in
    _initializeForCurrentUser();
  }

  void _initializeForCurrentUser() {
    // Cancel existing locations subscription
    _locationsSubscription?.cancel();
    _locationsSubscription = null;
    
    final user = _auth.currentUser;
    if (user == null) {
      // No user logged in, clear saved locations
      _savedLocationIds = [];
      _isLoading = false;
      notifyListeners();
      debugPrint('SavedLocationsProvider: No user, cleared saved locations');
      return;
    }

    debugPrint('SavedLocationsProvider: Initializing for user ${user.uid}');
    _isLoading = true;
    notifyListeners();

    // Start listening to the saved locations stream
    _locationsSubscription = _savedLocationsService.getSavedLocationsStream().listen(
      (locationIds) {
        debugPrint('SavedLocationsProvider: Received ${locationIds.length} saved locations');
        _savedLocationIds = locationIds;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('SavedLocationsProvider: Stream error: $error');
        _isLoading = false;
        notifyListeners();
      },
    );

    // Also do a one-time fetch to ensure we have the latest data
    _loadSavedLocations();
  }

  Future<void> _loadSavedLocations() async {
    try {
      final ids = await _savedLocationsService.getSavedLocations();
      _savedLocationIds = ids;
      _isLoading = false;
      notifyListeners();
      debugPrint('SavedLocationsProvider: Loaded ${ids.length} saved locations');
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('SavedLocationsProvider: Error loading saved locations: $e');
    }
  }

  /// Call this to manually refresh saved locations (e.g., after saving from the map)
  Future<void> refresh() async {
    await _loadSavedLocations();
  }

  Future<void> saveLocation(String locationId) async {
    await _savedLocationsService.saveLocation(locationId);
    // The stream will update _savedLocationIds automatically
  }

  Future<void> unsaveLocation(String locationId) async {
    await _savedLocationsService.unsaveLocation(locationId);
    // The stream will update _savedLocationIds automatically
  }

  @override
  void dispose() {
    _locationsSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
