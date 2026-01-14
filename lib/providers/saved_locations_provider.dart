import 'dart:async';
import 'package:flutter/material.dart';
import '../services/saved_locations_service.dart';

class SavedLocationsProvider with ChangeNotifier {
  final SavedLocationsService _savedLocationsService = SavedLocationsService();
  List<String> _savedLocationIds = [];
  StreamSubscription<List<String>>? _subscription;
  bool _isLoading = true;

  List<String> get savedLocationIds => _savedLocationIds;
  bool get isLoading => _isLoading;

  bool isSaved(String locationId) {
    return _savedLocationIds.contains(locationId);
  }

  SavedLocationsProvider() {
    _loadSavedLocations();
    _subscription = _savedLocationsService.getSavedLocationsStream().listen(
      (locationIds) {
        _savedLocationIds = locationIds;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        notifyListeners();
        debugPrint('Error in saved locations stream: $error');
      },
    );
  }

  Future<void> _loadSavedLocations() async {
    try {
      _isLoading = true;
      notifyListeners();
      final ids = await _savedLocationsService.getSavedLocations();
      _savedLocationIds = ids;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading saved locations: $e');
    }
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
    _subscription?.cancel();
    super.dispose();
  }
}
