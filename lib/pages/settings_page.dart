import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/user_profile_service.dart';
import '../widgets/user_name_editor.dart';
import '../providers/location_tracking_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final UserProfileService _userProfileService = UserProfileService();
  UserModel? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _userProfileService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> _toggleLocationTracking(BuildContext context) async {
    final provider = Provider.of<LocationTrackingProvider>(context, listen: false);
    try {
      await provider.toggleLocationTracking();
      if (mounted && provider.locationError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location error: ${provider.locationError}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userProfile == null
              ? const Center(child: Text('No profile data available'))
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        UserNameEditor(
                          currentName: _userProfile!.name ?? '',
                          onNameUpdated: (newName) {
                            setState(() {
                              _userProfile = UserModel(
                                uid: _userProfile!.uid,
                                email: _userProfile!.email,
                                displayName: _userProfile!.displayName,
                                photoURL: _userProfile!.photoURL,
                                name: newName,
                                createdAt: _userProfile!.createdAt,
                              );
                            });
                          },
                        ),
                        const SizedBox(height: 40),
                        // Location Awareness Section
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Location',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Location Button
                        Consumer<LocationTrackingProvider>(
                          builder: (context, locationProvider, _) {
                            final isTracking = locationProvider.isTrackingEnabled;
                            final isLoading = locationProvider.isLoadingLocation;
                            final currentLocation = locationProvider.currentLocation;
                            
                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: isLoading ? null : () => _toggleLocationTracking(context),
                                icon: isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(isTracking ? Icons.location_off : Icons.location_on),
                                label: Text(
                                  isLoading 
                                      ? 'Getting location...' 
                                      : (isTracking ? 'Turn Off Location' : 'Turn On Location'),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  foregroundColor: isTracking ? Colors.white : null,
                                  backgroundColor: isTracking ? Colors.red.shade600 : null,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        // Location Info Label/Tag
                        Consumer<LocationTrackingProvider>(
                          builder: (context, locationProvider, _) {
                            final currentLocation = locationProvider.currentLocation;
                            final locationError = locationProvider.locationError;
                            
                            if (currentLocation != null) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Current Location',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade900,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Latitude: ${currentLocation['latitude'].toStringAsFixed(6)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue.shade800,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    Text(
                                      'Longitude: ${currentLocation['longitude'].toStringAsFixed(6)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue.shade800,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Address: ${currentLocation['address']}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                    if (currentLocation['accuracy'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Accuracy: ${currentLocation['accuracy'].toStringAsFixed(1)}m',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue.shade600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            } else if (locationError != null) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        locationError,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.red.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              return const SizedBox.shrink();
                            }
                          },
                        ),

                      ],
                    ),
                  ),
                ),
    );
  }
}
