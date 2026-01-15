import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_profile_service.dart';
import '../widgets/user_name_editor.dart';

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
                      ],
                    ),
                  ),
                ),
    );
  }
}
