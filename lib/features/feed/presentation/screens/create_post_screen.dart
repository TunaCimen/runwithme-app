import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/models/route.dart' as route_model;
import '../../../../core/models/run_session.dart';
import '../../../auth/data/auth_service.dart';
import '../../../map/data/route_repository.dart';
import '../../../run/data/run_repository.dart';
import '../../../profile/data/image_api_client.dart';
import '../../data/models/feed_post_dto.dart';
import '../../data/models/create_post_dto.dart';
import '../../providers/feed_provider.dart';

typedef RunRoute = route_model.Route;

/// Screen for creating a new post
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  late FeedProvider _feedProvider;
  final _authService = AuthService();
  final _routeRepository = RouteRepository();
  final _runRepository = RunRepository();
  final _imageApiClient = ImageApiClient();
  final _imagePicker = ImagePicker();
  final _textController = TextEditingController();

  PostType _selectedType = PostType.text;
  PostVisibility _visibility = PostVisibility.public;
  int? _selectedRouteId;
  int? _selectedRunSessionId;

  // User's saved routes for selection
  List<RunRoute> _userRoutes = [];
  bool _loadingRoutes = false;
  RunRoute? _selectedRoute;

  // User's run sessions for selection
  List<RunSession> _userRuns = [];
  bool _loadingRuns = false;
  RunSession? _selectedRun;

  // Photo state
  File? _selectedImage;
  String? _uploadedImageUrl;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    _feedProvider = FeedProvider();

    final token = _authService.accessToken;
    if (token != null) {
      _feedProvider.setAuthToken(token);
      _imageApiClient.setAuthToken(token);
    }

    _loadUserRoutes();
    _loadUserRuns();
  }

  Future<void> _loadUserRoutes() async {
    final user = _authService.currentUser;
    final accessToken = _authService.accessToken;

    if (user == null || accessToken == null) return;

    setState(() {
      _loadingRoutes = true;
    });

    try {
      final routes = await _routeRepository.getUserLikedRoutes(
        userId: user.userId,
        page: 0,
        size: 50,
        accessToken: accessToken,
      );

      if (mounted) {
        setState(() {
          _userRoutes = routes;
          _loadingRoutes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingRoutes = false;
        });
      }
    }
  }

  Future<void> _loadUserRuns() async {
    final user = _authService.currentUser;
    final accessToken = _authService.accessToken;

    if (user == null || accessToken == null) return;

    setState(() {
      _loadingRuns = true;
    });

    try {
      final result = await _runRepository.getUserRuns(
        user.userId,
        accessToken: accessToken,
        page: 0,
        size: 50,
      );

      if (mounted) {
        setState(() {
          _userRuns = result.success ? (result.data ?? []) : [];
          _loadingRuns = false;
        });
      }
    } catch (e) {
      debugPrint('[CreatePostScreen] Error loading user runs: $e');
      if (mounted) {
        setState(() {
          _loadingRuns = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Create Post',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          ListenableBuilder(
            listenable: _feedProvider,
            builder: (context, _) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: ElevatedButton(
                  onPressed: _feedProvider.creatingPost ? null : _createPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7ED321),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _feedProvider.creatingPost
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Post'),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserHeader(),
            const SizedBox(height: 16),
            _buildPostTypeSelector(),
            const SizedBox(height: 16),
            _buildTextInput(),
            if (_selectedType == PostType.run) ...[
              const SizedBox(height: 16),
              _buildRunSelector(),
            ],
            if (_selectedType == PostType.route) ...[
              const SizedBox(height: 16),
              _buildRouteSelector(),
            ],
            const SizedBox(height: 16),
            _buildPhotoUpload(),
            const SizedBox(height: 16),
            _buildVisibilitySelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeader() {
    final user = _authService.currentUser;
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFF7ED321).withValues(alpha: 0.2),
          child: Text(
            user?.username.isNotEmpty == true
                ? user!.username[0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: Color(0xFF7ED321),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          user?.username ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildPostTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Post Type',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTypeChip(PostType.text, Icons.chat_bubble_outline, 'Text'),
            _buildTypeChip(PostType.run, Icons.directions_run, 'Run'),
            _buildTypeChip(PostType.route, Icons.map, 'Route'),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeChip(PostType type, IconData icon, String label) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          _selectedRouteId = null;
          _selectedRunSessionId = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF7ED321).withValues(alpha: 0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF7ED321) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFF7ED321) : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF7ED321) : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInput() {
    return TextField(
      controller: _textController,
      maxLines: 5,
      decoration: InputDecoration(
        hintText: _selectedType == PostType.text
            ? "What's on your mind?"
            : 'Add a description...',
        hintStyle: TextStyle(color: Colors.grey[400]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF7ED321)),
        ),
      ),
    );
  }

  Widget _buildPhotoUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add Photo (Optional)',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        if (_selectedImage != null) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _selectedImage!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _removePhoto,
                  ),
                ),
              ),
              if (_uploadingImage)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ] else
          InkWell(
            onTap: _showPhotoOptions,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate,
                    size: 32,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add a photo',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Add Photo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt,
                    color: Color(0xFF7ED321),
                  ),
                  title: const Text('Take a photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: Color(0xFF7ED321),
                  ),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        await _uploadImage();
      }
    } catch (e) {
      debugPrint('[CreatePostScreen] Error picking image: $e');
      if (mounted) {
        String errorMessage = 'Failed to pick image';
        if (e.toString().contains('permission') ||
            e.toString().contains('denied')) {
          errorMessage = 'Please grant camera/photo permissions in Settings';
        } else if (e.toString().contains('camera_access_denied')) {
          errorMessage = 'Camera access denied. Please enable in Settings';
        } else if (e.toString().contains('photo_access_denied')) {
          errorMessage =
              'Photo library access denied. Please enable in Settings';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        );
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;

    debugPrint(
      '[CreatePostScreen] Starting image upload: ${_selectedImage!.path}',
    );

    setState(() {
      _uploadingImage = true;
    });

    try {
      final result = await _imageApiClient.uploadImage(
        _selectedImage!.path,
        folder: 'posts',
      );

      debugPrint('[CreatePostScreen] Image upload successful: $result');

      if (mounted) {
        setState(() {
          _uploadingImage = false;
          _uploadedImageUrl = result;
        });
      }
    } catch (e) {
      debugPrint('[CreatePostScreen] Image upload failed: $e');
      if (mounted) {
        setState(() {
          _uploadingImage = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _selectedImage = null;
      _uploadedImageUrl = null;
    });
  }

  Widget _buildRunSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select a Run',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        if (_loadingRuns)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: CircularProgressIndicator()),
          )
        else if (_userRuns.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.directions_run, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No recent runs',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete a run to share it',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              // Selected run preview
              if (_selectedRun != null) ...[
                _buildSelectedRunCard(_selectedRun!),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _showRunSelectionSheet(),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Change Run'),
                ),
              ] else
                _buildRunSelectionButton(),
            ],
          ),
      ],
    );
  }

  Widget _buildRunSelectionButton() {
    return InkWell(
      onTap: () => _showRunSelectionSheet(),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF7ED321).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.directions_run, color: Color(0xFF7ED321)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a run',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                  ),
                  Text(
                    '${_userRuns.length} runs available',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedRunCard(RunSession run) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7ED321)),
      ),
      child: Column(
        children: [
          // Map preview if we have route points
          if (run.points.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
              child: SizedBox(
                height: 150,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(
                      run.points.first.latitude,
                      run.points.first.longitude,
                    ),
                    initialZoom: 13.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.runwithme_app',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: run.points
                              .map((p) => LatLng(p.latitude, p.longitude))
                              .toList(),
                          strokeWidth: 4.0,
                          color: const Color(0xFF7ED321),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          // Run info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        run.formattedDate,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.straighten,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            run.formattedDistance,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.timer, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            run.formattedDuration,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.speed, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            run.formattedPace,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: Color(0xFF7ED321)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRunSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select a Run',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _userRuns.length,
                    itemBuilder: (context, index) {
                      final run = _userRuns[index];
                      final isSelected = _selectedRunSessionId == run.id;
                      return _buildRunSelectionTile(run, isSelected);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRunSelectionTile(RunSession run, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF7ED321).withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF7ED321) : Colors.grey[300]!,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedRun = run;
            _selectedRunSessionId = run.id;
          });
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Run icon or mini map
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF7ED321).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: run.points.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(
                              run.points.first.latitude,
                              run.points.first.longitude,
                            ),
                            initialZoom: 12.0,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.runwithme_app',
                            ),
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: run.points
                                      .map(
                                        (p) => LatLng(p.latitude, p.longitude),
                                      )
                                      .toList(),
                                  strokeWidth: 2.0,
                                  color: const Color(0xFF7ED321),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : const Icon(
                        Icons.directions_run,
                        size: 32,
                        color: Color(0xFF7ED321),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      run.formattedDate,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          run.formattedDistance,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('•', style: TextStyle(color: Colors.grey[400])),
                        const SizedBox(width: 8),
                        Text(
                          run.formattedDuration,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('•', style: TextStyle(color: Colors.grey[400])),
                        const SizedBox(width: 8),
                        Text(
                          run.formattedPace,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: Color(0xFF7ED321)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select a Route',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        if (_loadingRoutes)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: CircularProgressIndicator()),
          )
        else if (_userRoutes.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.map, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No routes yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create or save a route to share it',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              // Selected route preview
              if (_selectedRoute != null) ...[
                _buildSelectedRouteCard(_selectedRoute!),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _showRouteSelectionSheet(),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Change Route'),
                ),
              ] else
                _buildRouteSelectionButton(),
            ],
          ),
      ],
    );
  }

  Widget _buildRouteSelectionButton() {
    return InkWell(
      onTap: () => _showRouteSelectionSheet(),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF7ED321).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.map, color: Color(0xFF7ED321)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a route',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                  ),
                  Text(
                    '${_userRoutes.length} routes available',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedRouteCard(RunRoute route) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7ED321)),
      ),
      child: Column(
        children: [
          // Map preview
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            child: SizedBox(
              height: 150,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(
                    (route.startPointLat + route.endPointLat) / 2,
                    (route.startPointLon + route.endPointLon) / 2,
                  ),
                  initialZoom: 13.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.runwithme_app',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: route.points.isNotEmpty
                            ? route.points
                                  .map((p) => LatLng(p.latitude, p.longitude))
                                  .toList()
                            : [
                                LatLng(
                                  route.startPointLat,
                                  route.startPointLon,
                                ),
                                LatLng(route.endPointLat, route.endPointLon),
                              ],
                        strokeWidth: 4.0,
                        color: const Color(0xFF7ED321),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Route info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.title ?? 'Untitled Route',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.straighten,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            route.formattedDistance,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.timer, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            route.formattedDuration,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: Color(0xFF7ED321)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRouteSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select a Route',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _userRoutes.length,
                    itemBuilder: (context, index) {
                      final route = _userRoutes[index];
                      final isSelected = _selectedRouteId == route.id;
                      return _buildRouteSelectionTile(route, isSelected);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRouteSelectionTile(RunRoute route, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF7ED321).withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF7ED321) : Colors.grey[300]!,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedRoute = route;
            _selectedRouteId = route.id;
          });
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Small map preview
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(
                        (route.startPointLat + route.endPointLat) / 2,
                        (route.startPointLon + route.endPointLon) / 2,
                      ),
                      initialZoom: 12.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.runwithme_app',
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: route.points.isNotEmpty
                                ? route.points
                                      .map(
                                        (p) => LatLng(p.latitude, p.longitude),
                                      )
                                      .toList()
                                : [
                                    LatLng(
                                      route.startPointLat,
                                      route.startPointLon,
                                    ),
                                    LatLng(
                                      route.endPointLat,
                                      route.endPointLon,
                                    ),
                                  ],
                            strokeWidth: 2.0,
                            color: const Color(0xFF7ED321),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.title ?? 'Untitled Route',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          route.formattedDistance,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('•', style: TextStyle(color: Colors.grey[400])),
                        const SizedBox(width: 8),
                        Text(
                          route.formattedDuration,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    if (route.difficulty != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getDifficultyColor(
                            route.difficulty!,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          route.difficulty!,
                          style: TextStyle(
                            fontSize: 11,
                            color: _getDifficultyColor(route.difficulty!),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: Color(0xFF7ED321)),
            ],
          ),
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      case 'very hard':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildVisibilitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Who can see this?',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildVisibilityOption(
                PostVisibility.public,
                Icons.public,
                'Everyone',
                'Anyone on RunWithMe can see',
              ),
              Divider(height: 1, color: Colors.grey[300]),
              _buildVisibilityOption(
                PostVisibility.friends,
                Icons.people,
                'Friends Only',
                'Only your friends can see',
              ),
              Divider(height: 1, color: Colors.grey[300]),
              _buildVisibilityOption(
                PostVisibility.private_,
                Icons.lock,
                'Only Me',
                'Only you can see this post',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVisibilityOption(
    PostVisibility visibility,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final isSelected = _visibility == visibility;
    return InkWell(
      onTap: () => setState(() => _visibility = visibility),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF7ED321) : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF7ED321)
                          : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check, color: Color(0xFF7ED321)),
          ],
        ),
      ),
    );
  }

  Future<void> _createPost() async {
    final text = _textController.text.trim();

    if (_selectedType == PostType.text && text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter some text')));
      return;
    }

    if (_selectedType == PostType.run && _selectedRunSessionId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a run')));
      return;
    }

    if (_selectedType == PostType.route && _selectedRouteId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a route')));
      return;
    }

    // Note: PHOTO type is not used by backend - TEXT posts can have optional mediaUrl

    // Check if image is still uploading
    if (_uploadingImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for image to finish uploading'),
        ),
      );
      return;
    }

    debugPrint('[CreatePostScreen] Creating post: postType=$_selectedType');
    debugPrint(
      '[CreatePostScreen]   routeId=$_selectedRouteId, runSessionId=$_selectedRunSessionId, mediaUrl=$_uploadedImageUrl',
    );

    final request = CreatePostDto(
      postType: _selectedType,
      textContent: text.isNotEmpty ? text : null,
      routeId: _selectedRouteId,
      runSessionId: _selectedRunSessionId,
      mediaUrl: _uploadedImageUrl,
      visibility: _visibility,
    );

    debugPrint('[CreatePostScreen] Request JSON: ${request.toJson()}');

    final result = await _feedProvider.createPost(request);

    debugPrint(
      '[CreatePostScreen] Create post result: success=${result.success}, message=${result.message}',
    );

    if (mounted) {
      if (result.success) {
        Navigator.pop(context, result.data);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Failed to create post')),
        );
      }
    }
  }
}
