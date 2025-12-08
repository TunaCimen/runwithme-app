import 'package:flutter/material.dart';
import '../../../auth/data/auth_service.dart';
import '../../data/models/feed_post_dto.dart';
import '../../data/models/create_post_dto.dart';
import '../../providers/feed_provider.dart';

/// Screen for creating a new post
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  late FeedProvider _feedProvider;
  final _authService = AuthService();
  final _textController = TextEditingController();

  PostType _selectedType = PostType.text;
  PostVisibility _visibility = PostVisibility.public;
  int? _selectedRouteId;
  int? _selectedRunSessionId;

  @override
  void initState() {
    super.initState();
    _feedProvider = FeedProvider();

    final token = _authService.accessToken;
    if (token != null) {
      _feedProvider.setAuthToken(token);
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
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
        Row(
          children: [
            _buildTypeChip(PostType.text, Icons.chat_bubble_outline, 'Text'),
            const SizedBox(width: 8),
            _buildTypeChip(PostType.run, Icons.directions_run, 'Run'),
            const SizedBox(width: 8),
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
        ),
      ],
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
        ),
      ],
    );
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
                      color: isSelected ? const Color(0xFF7ED321) : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, color: Color(0xFF7ED321)),
          ],
        ),
      ),
    );
  }

  Future<void> _createPost() async {
    final text = _textController.text.trim();

    if (_selectedType == PostType.text && text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text')),
      );
      return;
    }

    if (_selectedType == PostType.run && _selectedRunSessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a run')),
      );
      return;
    }

    if (_selectedType == PostType.route && _selectedRouteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a route')),
      );
      return;
    }

    final request = CreatePostDto(
      postType: _selectedType,
      textContent: text.isNotEmpty ? text : null,
      routeId: _selectedRouteId,
      runSessionId: _selectedRunSessionId,
      visibility: _visibility,
    );

    final result = await _feedProvider.createPost(request);

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
