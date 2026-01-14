import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import '../providers/auth_provider.dart';
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
  final UserProfileService _userProfileService = UserProfileService();
  UserModel? _userProfile;
  bool _isLoading = true;
  bool _isEditingName = false;
  bool _isSavingName = false;
  String? _nameError;
  bool _nameLengthLimitHit = false;
  late TextEditingController _nameController;
  static final RegExp _nameRegex = RegExp(r'^[a-zA-Z0-9]+$');

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadUserProfile();
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

  bool get _isNameValid {
    final value = _nameController.text.trim();
    return value.isNotEmpty && value.length <= 16 && _nameRegex.hasMatch(value);
  }

  String? _buildNameErrorText() {
    final value = _nameController.text.trim();
    final bool hasInvalidChars = value.isNotEmpty && !_nameRegex.hasMatch(value);
    final bool isTooLong = _nameLengthLimitHit;

    if (!hasInvalidChars && !isTooLong) return null;

    final parts = <String>[];
    if (hasInvalidChars) {
      parts.add('Only letters and numbers allowed in name.');
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
                            CircleAvatar(
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
                        // Placeholder for future features
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Profile features coming soon:\n• Edit username\n• Upload profile picture\n• View saved locations',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
