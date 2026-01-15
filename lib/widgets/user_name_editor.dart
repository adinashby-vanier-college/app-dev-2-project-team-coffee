import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/user_profile_service.dart';

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

class UserNameEditor extends StatefulWidget {
  final String currentName;
  final Function(String) onNameUpdated;

  const UserNameEditor({
    super.key,
    required this.currentName,
    required this.onNameUpdated,
  });

  @override
  State<UserNameEditor> createState() => _UserNameEditorState();
}

class _UserNameEditorState extends State<UserNameEditor> {
  late TextEditingController _nameController;
  final UserProfileService _userProfileService = UserProfileService();
  
  bool _isEditingName = false;
  bool _isSavingName = false;
  String? _nameError;
  bool _nameLengthLimitHit = false;

  // Letters, numbers, and spaces only. Spacing rules are enforced separately.
  static final RegExp _nameRegex = RegExp(r'^[a-zA-Z0-9 ]+$');

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void didUpdateWidget(UserNameEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentName != widget.currentName && !_isEditingName) {
      _nameController.text = widget.currentName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
      widget.onNameUpdated(newName);

      setState(() {
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
    return Column(
      children: [
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
                      widget.currentName.isNotEmpty
                          ? widget.currentName
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
                        _nameController.text = widget.currentName;
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
                          _nameController.text = widget.currentName;
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
      ],
    );
  }
}
