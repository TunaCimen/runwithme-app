import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/user_profile.dart';
import '../data/profile_repository.dart';
import '../../auth/data/auth_service.dart';

class EditProfilePage extends StatefulWidget {
  final UserProfile? existingProfile;

  const EditProfilePage({super.key, this.existingProfile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _profileRepository = ProfileRepository();
  final _imagePicker = ImagePicker();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;

  DateTime? _birthday;
  String? _expertLevel;
  String? _pronouns;
  bool _profileVisibility = true;
  bool _isLoading = false;
  bool _isUploadingImage = false;

  // Profile picture state
  File? _selectedImage;
  String? _profilePicUrl;

  final List<String> _expertLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Expert',
  ];

  final List<String> _pronounOptions = [
    'he/him',
    'she/her',
    'they/them',
  ];

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.existingProfile?.firstName ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.existingProfile?.lastName ?? '',
    );
    _birthday = widget.existingProfile?.birthday;
    _expertLevel = widget.existingProfile?.expertLevel ?? 'Beginner';
    _profileVisibility = widget.existingProfile?.profileVisibility ?? true;

    // Set pronouns from existing profile (only if it matches one of the options)
    final existingPronouns = widget.existingProfile?.pronouns;
    if (existingPronouns != null && _pronounOptions.contains(existingPronouns)) {
      _pronouns = existingPronouns;
    }

    // Load existing profile picture URL
    if (widget.existingProfile?.profilePic != null) {
      _profilePicUrl = _getFullProfilePicUrl(
        widget.existingProfile!.profilePic!,
      );
    }
  }

  /// Get full URL for profile picture
  String _getFullProfilePicUrl(String filename) {
    if (filename.startsWith('http://') || filename.startsWith('https://')) {
      return filename;
    }
    return _profileRepository.getProfilePictureUrl(filename);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  /// Show image picker options
  Future<void> _showImagePickerOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF7ED321),
                    child: Icon(Icons.camera_alt, color: Colors.white),
                  ),
                  title: const Text('Take Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[400],
                    child: const Icon(Icons.photo_library, color: Colors.white),
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                if (_selectedImage != null || _profilePicUrl != null)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red[400],
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    title: const Text('Remove Photo'),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedImage = null;
                        _profilePicUrl = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Pick image from camera or gallery
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });

        // Upload immediately after picking
        await _uploadProfilePicture();
      }
    } catch (e) {
      debugPrint('[EditProfilePage] Error picking image: $e');
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  /// Upload the selected profile picture
  Future<void> _uploadProfilePicture() async {
    if (_selectedImage == null) return;

    final user = _authService.currentUser;
    final accessToken = _authService.accessToken;

    if (user == null || accessToken == null) {
      _showErrorSnackBar('Authentication required');
      return;
    }

    setState(() => _isUploadingImage = true);

    final result = await _profileRepository.uploadProfilePicture(
      user.userId,
      _selectedImage!.path,
      accessToken: accessToken,
    );

    if (!mounted) return;
    setState(() => _isUploadingImage = false);

    if (result.success && result.profilePicUrl != null) {
      setState(() {
        _profilePicUrl = _getFullProfilePicUrl(result.profilePicUrl!);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture uploaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      _showErrorSnackBar(result.message);
      // Clear the selected image on failure
      setState(() {
        _selectedImage = null;
      });
    }
  }

  Future<void> _selectBirthday() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF7ED321)),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _birthday = pickedDate;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _authService.currentUser;
    if (user == null) {
      _showErrorSnackBar('User not logged in');
      return;
    }

    final accessToken = _authService.accessToken;
    if (accessToken == null) {
      _showErrorSnackBar('Authentication required');
      return;
    }

    setState(() => _isLoading = true);

    // Extract filename from URL for saving
    String? profilePicFilename;
    if (_profilePicUrl != null) {
      // Extract just the filename if it's a full URL
      final uri = Uri.tryParse(_profilePicUrl!);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        profilePicFilename = uri.pathSegments.last;
      } else {
        profilePicFilename = _profilePicUrl;
      }
    }

    final profile = UserProfile(
      userId: user.userId,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      pronouns: _pronouns,
      birthday: _birthday,
      expertLevel: _expertLevel,
      profileVisibility: _profileVisibility,
      profilePic: profilePicFilename,
    );

    final result = widget.existingProfile == null
        ? await _profileRepository.createProfile(
            profile,
            accessToken: accessToken,
          )
        : await _profileRepository.updateProfile(
            profile,
            accessToken: accessToken,
          );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, result.profile);
    } else {
      _showErrorSnackBar(result.message);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingProfile == null ? 'Create Profile' : 'Edit Profile',
        ),
        backgroundColor: const Color(0xFF7ED321),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Picture
                Center(
                  child: GestureDetector(
                    onTap: _isUploadingImage ? null : _showImagePickerOptions,
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                            image: _selectedImage != null
                                ? DecorationImage(
                                    image: FileImage(_selectedImage!),
                                    fit: BoxFit.cover,
                                  )
                                : _profilePicUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(_profilePicUrl!),
                                    fit: BoxFit.cover,
                                    onError: (exception, stackTrace) {
                                      debugPrint(
                                        '[EditProfilePage] Error loading profile pic: $exception',
                                      );
                                    },
                                  )
                                : null,
                          ),
                          child:
                              (_selectedImage == null && _profilePicUrl == null)
                              ? Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey[400],
                                )
                              : null,
                        ),
                        // Loading indicator
                        if (_isUploadingImage)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              ),
                            ),
                          ),
                        // Camera button
                        if (!_isUploadingImage)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: Color(0xFF7ED321),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Tap to change photo',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
                const SizedBox(height: 32),

                // First Name
                TextFormField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'First Name *',
                    hintText: 'Enter your first name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'First name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Last Name
                TextFormField(
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Last Name *',
                    hintText: 'Enter your last name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Last name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Pronouns (Optional)
                DropdownButtonFormField<String>(
                  value: _pronouns,
                  decoration: InputDecoration(
                    labelText: 'Pronouns (Optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.wc),
                  ),
                  hint: const Text('Select pronouns'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Prefer not to say'),
                    ),
                    ..._pronounOptions.map((pronoun) {
                      return DropdownMenuItem(
                        value: pronoun,
                        child: Text(pronoun),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _pronouns = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Birthday
                InkWell(
                  onTap: _selectBirthday,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Birthday',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.cake_outlined),
                    ),
                    child: Text(
                      _birthday == null
                          ? 'Select your birthday'
                          : '${_birthday!.day}/${_birthday!.month}/${_birthday!.year}',
                      style: TextStyle(
                        color: _birthday == null
                            ? Colors.grey[600]
                            : Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Expert Level
                DropdownButtonFormField<String>(
                  value: _expertLevel,
                  decoration: InputDecoration(
                    labelText: 'Running Level',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.directions_run),
                  ),
                  items: _expertLevels.map((level) {
                    return DropdownMenuItem(value: level, child: Text(level));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _expertLevel = value;
                    });
                  },
                ),
                const SizedBox(height: 24),

                // Profile Visibility
                Card(
                  elevation: 0,
                  color: Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  child: SwitchListTile(
                    title: const Text('Public Profile'),
                    subtitle: const Text('Allow others to see your profile'),
                    value: _profileVisibility,
                    activeTrackColor: const Color(
                      0xFF7ED321,
                    ).withValues(alpha: 0.5),
                    thumbColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const Color(0xFF7ED321);
                      }
                      return null;
                    }),
                    onChanged: (value) {
                      setState(() {
                        _profileVisibility = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7ED321),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Profile',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
