import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import '../providers/auth_provider.dart';
import '../services/storage_service.dart';
import '../services/saved_locations_service.dart';
import '../pages/home_page.dart';
import '../services/user_profile_service.dart';
import '../models/user_model.dart';

class _MaxLenNotifierFormatter extends TextInputFormatter {
  final int maxLength;
  final VoidCallback onLimitHit;

  _MaxLenNotifierFormatter({
    required this.maxLength,
    required this.onLimitHit,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= maxLength) {
      return newValue;
    }

    // User attempted to exceed max length: keep old value but notify.
    WidgetsBinding.instance.addPostFrameCallback((_) => onLimitHit());
    return oldValue;
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final StorageService _storageService = StorageService();
  final UserProfileService _userProfileService = UserProfileService();
  final SavedLocationsService _savedLocationsService = SavedLocationsService();
  UserModel? _userProfile;
  bool _isLoading = true;
  bool _isEditingName = false;
  bool _isSavingName = false;
  bool _isUploadingPhoto = false;
  String? _nameError;
  bool _nameLengthLimitHit = false;
  late TextEditingController _nameController;
  // Letters, numbers, and spaces only. Spacing rules are enforced separately.
  static final RegExp _nameRegex = RegExp(r'^[a-zA-Z0-9 ]+$');

  List<String> _savedLocationIds = [];
  bool _isLoadingSavedLocations = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadUserProfile();
    _loadSavedLocations();
  }

  @override
  void dispose() {
    _nameController.dispose();
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
          _nameController.text = profile.name ?? '';
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

  Future<void> _loadSavedLocations() async {
    setState(() {
      _isLoadingSavedLocations = true;
    });

    try {
      final ids = await _savedLocationsService.getSavedLocations();
      if (mounted) {
        setState(() {
          _savedLocationIds = ids;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading saved locations: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSavedLocations = false;
        });
      }
    }
  }

  bool get _isNameValid {
    final value = _nameController.text;
    final trimmed = value.trim();

    if (trimmed.isEmpty || trimmed.length > 16) {
      return false;
    }

    // Only letters, numbers and spaces allowed in the raw value
    if (trimmed.isNotEmpty && !_nameRegex.hasMatch(value)) {
      return false;
    }

    // Spacing rule: no leading/trailing spaces and no double spaces
    if (_hasSpacingIssue(value)) {
      return false;
    }

    return true;
  }

  bool _hasSpacingIssue(String value) {
    if (value.isEmpty) return false;
    if (value.startsWith(' ') || value.endsWith(' ')) return true;
    if (value.contains('  ')) return true; // double space anywhere
    return false;
  }

  String? _buildNameErrorText() {
    final raw = _nameController.text;
    final trimmed = raw.trim();
    final bool hasInvalidChars =
        trimmed.isNotEmpty && !_nameRegex.hasMatch(raw);
    final bool isTooLong = _nameLengthLimitHit || trimmed.length > 16;
    final bool hasSpacingIssue = _hasSpacingIssue(raw);

    if (!hasInvalidChars && !isTooLong && !hasSpacingIssue) return null;

    final parts = <String>[];
    if (hasInvalidChars) {
      parts.add('Only letters and numbers allowed in name.');
    }
    if (hasSpacingIssue) {
      parts.add("Single space only between words. Ex: 'Tim Cook'.");
    }
    if (isTooLong) {
      parts.add('Up to 16 characters allowed.');
    }
    return parts.join(' ');
  }

  Future<void> _saveUserName() async {
    final newName = _nameController.text.trim();
    if (_userProfile == null) {
      return;
    }

    if (!_isNameValid) {
      setState(() {
        _nameError = _buildNameErrorText() ??
            'Only letters and numbers allowed in name.';
      });
      return;
    }

    setState(() {
      _isSavingName = true;
    });

    try {
      await _userProfileService.updateUserName(newName);

      setState(() {
        _userProfile = UserModel(
          uid: _userProfile!.uid,
          email: _userProfile!.email,
          displayName: _userProfile!.displayName,
          photoURL: _userProfile!.photoURL,
          name: newName,
          createdAt: _userProfile!.createdAt,
        );
        _isEditingName = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating name: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingName = false;
        });
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

  void _openLocationFromProfile(String locationId) {
    // Navigate to HomePage with the initial location ID so that
    // GoogleMapsUIWidget can open the same map modal.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => HomePage(initialLocationId: locationId),
      ),
      (route) => false,
    );
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
                      SizedBox(
                        width: 320,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            _isEditingName
                                ? TextField(
                                    controller: _nameController,
                                    textAlign: TextAlign.center,
                                    maxLength: 16,
                                    inputFormatters: [
                                      _MaxLenNotifierFormatter(
                                        maxLength: 16,
                                        onLimitHit: () {
                                          if (!_nameLengthLimitHit) {
                                            setState(() {
                                              _nameLengthLimitHit = true;
                                              _nameError = _buildNameErrorText();
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        if (value.length < 16) {
                                          _nameLengthLimitHit = false;
                                        }
                                        _nameError = _buildNameErrorText();
                                      });
                                    },
                                    decoration: const InputDecoration(
                                      hintText: 'Enter your name',
                                      border: UnderlineInputBorder(),
                                      isDense: true,
                                      counterText: '',
                                    ),
                                  )
                                : Text(
                                    _userProfile!.name?.isNotEmpty == true
                                        ? _userProfile!.name!
                                        : 'No name set',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                            if (!_isEditingName)
                              Positioned(
                                right: 0,
                                child: IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  tooltip: 'Edit name',
                                  onPressed: () {
                                    setState(() {
                                      _isEditingName = true;
                                      _nameController.text =
                                          _userProfile!.name ?? '';
                                    });
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_isEditingName) ...[
                        const SizedBox(height: 8),
                        if (_nameError != null) ...[
                          Text(
                            _nameError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: _isSavingName
                                  ? null
                                  : () {
                                      setState(() {
                                        _isEditingName = false;
                                        _nameError = null;
                                        _nameLengthLimitHit = false;
                                        _nameController.text =
                                            _userProfile!.name ?? '';
                                      });
                                    },
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed:
                                  (_isSavingName || !_isNameValid)
                                      ? null
                                      : () => _saveUserName(),
                              child: _isSavingName
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Save'),
                            ),
                          ],
                        ),
                      ],
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
                        if (_isLoadingSavedLocations)
                          const Center(child: CircularProgressIndicator())
                        else if (_savedLocationIds.isEmpty)
                          Container(
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
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _savedLocationIds.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final locationId = _savedLocationIds[index];
                              return _SavedLocationCard(
                                locationId: locationId,
                                onTap: () => _openLocationFromProfile(locationId),
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
