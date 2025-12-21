import 'package:flutter/material.dart';
import '../../../core/models/route.dart' as route_model;
import '../../auth/data/auth_service.dart';
import '../../map/data/route_repository.dart';

typedef RunRoute = route_model.Route;

class EditRoutePage extends StatefulWidget {
  final RunRoute route;
  final AuthService authService;
  final RouteRepository routeRepository;

  const EditRoutePage({
    super.key,
    required this.route,
    required this.authService,
    required this.routeRepository,
  });

  @override
  State<EditRoutePage> createState() => _EditRoutePageState();
}

class _EditRoutePageState extends State<EditRoutePage> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  String? _selectedDifficulty;
  bool _isPublic = true;
  bool _isSaving = false;

  final List<String> _difficulties = ['Easy', 'Medium', 'Hard', 'Very Hard'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.route.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.route.description ?? '',
    );
    _selectedDifficulty = widget.route.difficulty;
    _isPublic = widget.route.isPublic;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveRoute() async {
    final accessToken = widget.authService.accessToken;
    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save changes')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    // Update only editable fields
    final result = await widget.routeRepository.updateRouteFields(
      routeId: widget.route.id,
      title: _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      difficulty: _selectedDifficulty,
      isPublic: _isPublic,
      accessToken: accessToken,
    );

    setState(() {
      _isSaving = false;
    });

    if (mounted) {
      if (result.success && result.route != null) {
        Navigator.pop(context, result.route);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route updated successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Failed to update route')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Route'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: CircularProgressIndicator(),
              ),
            )
          else
            TextButton(
              onPressed: _saveRoute,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Color(0xFF7ED321),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title field
            const Text(
              'Route Title',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Enter route title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF7ED321)),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),

            // Description field
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe your route...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF7ED321)),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),

            // Difficulty selection
            const Text(
              'Difficulty',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _difficulties.map((difficulty) {
                final isSelected = _selectedDifficulty == difficulty;
                return ChoiceChip(
                  label: Text(difficulty),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedDifficulty = selected ? difficulty : null;
                    });
                  },
                  selectedColor: const Color(0xFF7ED321),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  backgroundColor: Colors.grey[200],
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF7ED321)
                        : Colors.grey[300]!,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Visibility toggle
            const Text(
              'Visibility',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E5E5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: const Text('Public Route'),
                subtitle: Text(
                  _isPublic ? 'Visible to all users' : 'Only visible to you',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                value: _isPublic,
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
                    _isPublic = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 24),

            // Route stats (read-only)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Route Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(
                        icon: Icons.straighten,
                        value: widget.route.formattedDistance,
                        label: 'Distance',
                      ),
                      _buildStatColumn(
                        icon: Icons.timer,
                        value: widget.route.formattedDuration,
                        label: 'Duration',
                      ),
                      _buildStatColumn(
                        icon: Icons.pin_drop,
                        value: '${widget.route.points.length}',
                        label: 'Points',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
