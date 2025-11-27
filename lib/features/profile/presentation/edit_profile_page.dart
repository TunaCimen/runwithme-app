import 'package:flutter/material.dart';
import '../../../core/models/user_profile.dart';
import '../data/profile_repository.dart';
import '../../auth/data/auth_service.dart';

class EditProfilePage extends StatefulWidget {
  final UserProfile? existingProfile;

  const EditProfilePage({
    super.key,
    this.existingProfile,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _profileRepository = ProfileRepository();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _pronounsController;

  DateTime? _birthday;
  String? _expertLevel;
  bool _profileVisibility = true;
  bool _isLoading = false;

  final List<String> _expertLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Expert',
  ];

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.existingProfile?.firstName ?? '');
    _lastNameController = TextEditingController(text: widget.existingProfile?.lastName ?? '');
    _pronounsController = TextEditingController(text: widget.existingProfile?.pronouns ?? '');
    _birthday = widget.existingProfile?.birthday;
    _expertLevel = widget.existingProfile?.expertLevel ?? 'Beginner';
    _profileVisibility = widget.existingProfile?.profileVisibility ?? true;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _pronounsController.dispose();
    super.dispose();
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
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7ED321),
            ),
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

    final profile = UserProfile(
      userId: user.userId,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      pronouns: _pronounsController.text.trim().isEmpty ? null : _pronounsController.text.trim(),
      birthday: _birthday,
      expertLevel: _expertLevel,
      profileVisibility: _profileVisibility,
    );

    final result = widget.existingProfile == null
        ? await _profileRepository.createProfile(profile, accessToken: accessToken)
        : await _profileRepository.updateProfile(profile, accessToken: accessToken);

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
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingProfile == null ? 'Create Profile' : 'Edit Profile'),
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
                // Profile Picture Placeholder
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                      ),
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
                TextFormField(
                  controller: _pronounsController,
                  decoration: InputDecoration(
                    labelText: 'Pronouns (Optional)',
                    hintText: 'e.g., she/her, he/him, they/them',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.wc),
                  ),
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
                        color: _birthday == null ? Colors.grey[600] : Colors.black87,
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
                    return DropdownMenuItem(
                      value: level,
                      child: Text(level),
                    );
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
                    activeColor: const Color(0xFF7ED321),
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
