import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../services/saved_locations_service.dart';
import '../services/locations_service.dart';
import '../models/location_details.dart';
import '../widgets/location_preview_card.dart';
import '../widgets/location_detail_sheet.dart';

class FriendProfilePage extends StatefulWidget {
  final UserModel user;

  const FriendProfilePage({super.key, required this.user});

  @override
  State<FriendProfilePage> createState() => _FriendProfilePageState();
}

class _FriendProfilePageState extends State<FriendProfilePage> {
  final SavedLocationsService _savedLocationsService = SavedLocationsService();
  final LocationsService _locationsService = LocationsService();

  Future<void> _openLocation(String locationId) async {
    // Show loading indicator or simple visual feedback could be nice, 
    // but LocationDetailSheet needs the full object.
    
    try {
      final locationData = await _locationsService.getLocationById(locationId);
      if (locationData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location details not found')),
          );
        }
        return;
      }

      final location = _convertMapToLocationDetails(locationData);

      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => LocationDetailSheet(
            location: location,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading location: $e')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user.displayName ?? 'Friend Profile'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Profile Picture
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: widget.user.photoURL != null &&
                        widget.user.photoURL!.isNotEmpty
                    ? CachedNetworkImageProvider(widget.user.photoURL!)
                    : null,
                child:
                    widget.user.photoURL == null || widget.user.photoURL!.isEmpty
                        ? Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.grey.shade600,
                          )
                        : null,
              ),
              const SizedBox(height: 16),
              // Name
              Text(
                widget.user.displayName ?? 'No Name',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Email
              Text(
                widget.user.email ?? '',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
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
              
              StreamBuilder<List<String>>(
                stream: _savedLocationsService.getSavedLocationsStreamForUser(widget.user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final savedLocationIds = snapshot.data ?? [];

                  if (savedLocationIds.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'No saved locations yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: savedLocationIds.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final locationId = savedLocationIds[index];
                      return LocationPreviewCard(
                        locationId: locationId,
                        onTap: () => _openLocation(locationId),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
