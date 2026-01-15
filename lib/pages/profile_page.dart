import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/saved_locations_provider.dart';
import '../providers/location_tracking_provider.dart';
import '../services/storage_service.dart';
import '../services/user_profile_service.dart';
import '../models/user_model.dart';
import '../services/locations_service.dart';
import '../models/location_details.dart';
import '../widgets/location_detail_sheet.dart';
import '../widgets/user_name_editor.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final StorageService _storageService = StorageService();
  final UserProfileService _userProfileService = UserProfileService();
  final LocationsService _locationsService = LocationsService();
  UserModel? _userProfile;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _userProfileService.getCurrentUserProfile();
      setState(() {
        _userProfile = profile;
        _isLoading = false;
        if (profile != null) {
          // Name handling removed
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }



  Future<void> _pickAndUploadPhoto({required bool fromCamera}) async {
    if (_isUploadingPhoto) return;

    try {
      setState(() {
        _isUploadingPhoto = true;
      });

      final imageFile = await _storageService.pickImage(fromCamera: fromCamera);
      if (imageFile == null) {
        return; // user cancelled
      }

      // Replace existing picture (optional cleanup)
      await _storageService.deleteProfilePicture();

      final downloadUrl =
          await _storageService.uploadProfilePicture(imageFile);
      await _userProfileService.updateProfilePicture(downloadUrl);

      setState(() {
        _userProfile = UserModel(
          uid: _userProfile!.uid,
          email: _userProfile!.email,
          displayName: _userProfile!.displayName,
          photoURL: downloadUrl,
          name: _userProfile!.name,
          createdAt: _userProfile!.createdAt,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _removePhoto() async {
    if (_isUploadingPhoto) return;
    try {
      setState(() {
        _isUploadingPhoto = true;
      });

      await _storageService.deleteProfilePicture();
      await _userProfileService.updateProfilePicture('');

      setState(() {
        _userProfile = UserModel(
          uid: _userProfile!.uid,
          email: _userProfile!.email,
          displayName: _userProfile!.displayName,
          photoURL: '',
          name: _userProfile!.name,
          createdAt: _userProfile!.createdAt,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final hasPhoto =
            _userProfile?.photoURL != null && _userProfile!.photoURL!.isNotEmpty;
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndUploadPhoto(fromCamera: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndUploadPhoto(fromCamera: true);
                },
              ),
              if (hasPhoto)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove photo',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _removePhoto();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openLocationFromProfile(String locationId) async {
    // Always fetch from Firebase
    LocationDetails? location;
    try {
      final locationData = await _locationsService.getLocationById(locationId);
      if (locationData != null) {
        location = _convertMapToLocationDetails(locationData);
      }
    } catch (e) {
      debugPrint('Error fetching location from Firebase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading location: $e')),
        );
      }
      return;
    }

    if (location == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location details not found')),
        );
      }
      return;
    }

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => LocationDetailSheet(
          location: location!,
        ),
      );
    }
  }

  LocationDetails _convertMapToLocationDetails(Map<String, dynamic> data) {
    // Convert hours array from Firebase format to DayHours objects
    List<DayHours> hours = [];
    if (data['hours'] != null && data['hours'] is List) {
      hours = (data['hours'] as List).map((hour) {
        return DayHours(
          day: hour['day'] as String? ?? '',
          time: hour['time'] as String? ?? '',
        );
      }).toList();
    }

    return LocationDetails(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? 'Unknown Location',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      reviews: data['reviews'] as String? ?? '0',
      price: data['price'] as String?,
      category: data['category'] as String? ?? 'Location',
      address: data['address'] as String? ?? '',
      openStatus: data['openStatus'] as String?,
      closeTime: data['closeTime'] as String?,
      phone: data['phone'] as String?,
      website: data['website'] as String?,
      description: data['description'] as String? ?? '',
      hours: hours,
    );
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
        title: const Text('Profile'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userProfile == null
              ? const Center(child: Text('No profile data available'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        // Profile Picture
                        Stack(
                          children: [
                          GestureDetector(
                            onTap: _isUploadingPhoto ? null : _showPhotoOptions,
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage:
                                  _userProfile!.photoURL != null &&
                                          _userProfile!.photoURL!.isNotEmpty
                                      ? CachedNetworkImageProvider(
                                          _userProfile!.photoURL!)
                                      : null,
                              child: _userProfile!.photoURL == null ||
                                      _userProfile!.photoURL!.isEmpty
                                  ? Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.grey.shade600,
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _isUploadingPhoto
                                  ? const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Colors.black54,
                                    ),
                            ),
                          ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      // Username + Edit controls
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
                        const SizedBox(height: 8),
                        // Email
                        Text(
                          _userProfile!.email ?? 'No email',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
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
                        const SizedBox(height: 40),
                        // Saved Locations Section
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Saved locations',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Consumer<SavedLocationsProvider>(
                          builder: (context, provider, _) {
                            if (provider.isLoading) {
                              return const Center(child: CircularProgressIndicator());
                            } else if (provider.savedLocationIds.isEmpty) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Saved locations will appear here when you tap the bookmark icon on the map.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              );
                            } else {
                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: provider.savedLocationIds.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final locationId = provider.savedLocationIds[index];
                                  return _SavedLocationCard(
                                    locationId: locationId,
                                    onTap: () => _openLocationFromProfile(locationId),
                                  );
                                },
                              );
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

class _SavedLocationCard extends StatelessWidget {
  final String locationId;
  final VoidCallback onTap;

  const _SavedLocationCard({
    required this.locationId,
    required this.onTap,
  });

  Map<String, dynamic>? _findLocation() {
    // LOCATION_DATABASE is defined in the web layer (JS), so on the Dart side
    // we only have the ID. For now we just show the ID; the full details will
    // come from the map modal when opened.
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final location = _findLocation();
    final title = location != null ? (location['name'] as String? ?? locationId) : locationId;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.place,
                size: 20,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to view details on the map',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
