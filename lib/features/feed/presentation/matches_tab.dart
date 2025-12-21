import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/route.dart' as route_model;
import '../../../core/models/user_profile.dart';
import '../../../core/utils/profile_pic_helper.dart';
import '../../auth/data/auth_service.dart';
import '../../map/data/route_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/user_profile_page.dart';
import '../../survey/data/survey_repository.dart';
import '../../survey/data/models/survey_response_dto.dart';
import '../../survey/presentation/questionnaire_screen.dart';

typedef RunRoute = route_model.Route;

/// Model for a matched user with their match score
class MatchedUser {
  final UserProfile profile;
  final int matchScore; // 0-100
  final List<RunRoute> routes;

  MatchedUser({
    required this.profile,
    required this.matchScore,
    this.routes = const [],
  });

  String get displayName {
    if (profile.firstName != null && profile.firstName!.isNotEmpty) {
      return profile.firstName!;
    }
    return profile.fullName.isNotEmpty
        ? profile.fullName.split(' ').first
        : 'Runner';
  }
}

class MatchesTab extends StatefulWidget {
  const MatchesTab({super.key});

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab> {
  final RouteRepository _routeRepository = RouteRepository();
  final AuthService _authService = AuthService();
  final ProfileRepository _profileRepository = ProfileRepository();
  final SurveyRepository _surveyRepository = SurveyRepository.instance;
  final Random _random = Random();

  List<RunRoute> _publicRoutes = [];
  List<MatchedUser> _matchedUsers = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Survey state
  SurveyResponseDto? _surveyResponse;
  bool _hasSurveyBeenChecked = false;
  bool _showQuestionnaireBanner = false;

  // Selected user filter (null = show all)
  String? _selectedUserId;

  // Like state
  final Map<int, bool> _likedRoutes = {};
  final Map<int, int> _likeCounts = {};

  // Creator profiles cache
  final Map<String, UserProfile> _creatorProfiles = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Load both users and routes
  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (forceRefresh) {
      _routeRepository.clearCache();
      _profileRepository.clearCache();
      _surveyRepository.clearCache();
    }

    // Load users, routes, and survey in parallel
    await Future.wait([
      _loadMatchedUsers(forceRefresh: forceRefresh),
      _loadPublicRoutes(forceRefresh: forceRefresh),
      _loadSurveyResponse(forceRefresh: forceRefresh),
    ]);

    // Assign routes to matched users
    _assignRoutesToUsers();

    setState(() {
      _isLoading = false;
    });
  }

  /// Load user's survey response to check if questionnaire is needed
  Future<void> _loadSurveyResponse({bool forceRefresh = false}) async {
    final accessToken = _authService.accessToken;
    if (accessToken == null) return;

    final result = await _surveyRepository.getMySurveyResponse(
      accessToken: accessToken,
      forceRefresh: forceRefresh,
    );

    if (mounted) {
      setState(() {
        _hasSurveyBeenChecked = true;
        _surveyResponse = result.data;
        _showQuestionnaireBanner = _surveyResponse == null;
      });
    }
  }

  /// Open the questionnaire screen
  Future<void> _openQuestionnaire() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionnaireScreen(
          existingResponse: _surveyResponse,
          onComplete: () {
            // Reload survey response after completion
            _loadSurveyResponse(forceRefresh: true);
          },
        ),
      ),
    );

    if (result == true) {
      // Survey was saved, refresh data
      _loadSurveyResponse(forceRefresh: true);
    }
  }

  /// Load matched users from backend
  Future<void> _loadMatchedUsers({bool forceRefresh = false}) async {
    final accessToken = _authService.accessToken;
    if (accessToken == null) return;

    final currentUserId = _authService.currentUser?.userId;

    final result = await _profileRepository.getAllProfiles(
      accessToken: accessToken,
      page: 0,
      size: 20,
      forceRefresh: forceRefresh,
    );

    if (result.success) {
      // Filter out current user and create matched users with random scores
      final profiles = result.profiles
          .where((p) => p.userId != currentUserId)
          .toList();

      _matchedUsers = profiles.map((profile) {
        // Generate random match score between 75-99 for demo
        final matchScore = 75 + _random.nextInt(25);
        return MatchedUser(profile: profile, matchScore: matchScore);
      }).toList();

      // Sort by match score (highest first)
      _matchedUsers.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    }
  }

  /// Load public routes
  Future<void> _loadPublicRoutes({bool forceRefresh = false}) async {
    final result = await _routeRepository.getPublicRoutes(
      page: 0,
      size: 50,
      accessToken: _authService.accessToken,
      forceRefresh: forceRefresh,
    );

    if (result.success && result.routes != null) {
      final fullRoutes = await _routeRepository.fetchFullRouteDetails(
        routes: result.routes!,
        accessToken: _authService.accessToken,
      );

      _publicRoutes = fullRoutes;
      _publicRoutes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Load like status and creator profiles
      _loadAllLikeStatuses(_publicRoutes, forceRefresh: forceRefresh);
      _loadAllCreatorProfiles(_publicRoutes, forceRefresh: forceRefresh);
    } else {
      _errorMessage = result.message ?? 'Failed to load routes';
    }
  }

  /// Assign routes to matched users based on creatorId
  void _assignRoutesToUsers() {
    for (var i = 0; i < _matchedUsers.length; i++) {
      final userRoutes = _publicRoutes
          .where((r) => r.creatorId == _matchedUsers[i].profile.userId)
          .toList();

      _matchedUsers[i] = MatchedUser(
        profile: _matchedUsers[i].profile,
        matchScore: _matchedUsers[i].matchScore,
        routes: userRoutes,
      );
    }
  }

  /// Get filtered routes based on selected user
  List<RunRoute> get _filteredRoutes {
    if (_selectedUserId == null) {
      return _publicRoutes;
    }
    return _publicRoutes.where((r) => r.creatorId == _selectedUserId).toList();
  }

  /// Get selected matched user
  MatchedUser? get _selectedMatchedUser {
    if (_selectedUserId == null) return null;
    try {
      return _matchedUsers.firstWhere(
        (u) => u.profile.userId == _selectedUserId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Load all like statuses in parallel
  Future<void> _loadAllLikeStatuses(
    List<RunRoute> routes, {
    bool forceRefresh = false,
  }) async {
    if (_authService.accessToken == null) return;

    const batchSize = 10;
    for (var i = 0; i < routes.length; i += batchSize) {
      final batchEnd = (i + batchSize < routes.length)
          ? i + batchSize
          : routes.length;
      final batch = routes.sublist(i, batchEnd);

      await Future.wait(
        batch.map(
          (route) => _loadLikeStatus(route.id, forceRefresh: forceRefresh),
        ),
      );
    }
  }

  /// Load all creator profiles in parallel
  Future<void> _loadAllCreatorProfiles(
    List<RunRoute> routes, {
    bool forceRefresh = false,
  }) async {
    final creatorIds = routes
        .where(
          (r) =>
              r.creatorId != null &&
              (forceRefresh || !_creatorProfiles.containsKey(r.creatorId)),
        )
        .map((r) => r.creatorId!)
        .toSet()
        .toList();

    if (creatorIds.isEmpty) return;

    const batchSize = 10;
    for (var i = 0; i < creatorIds.length; i += batchSize) {
      final batchEnd = (i + batchSize < creatorIds.length)
          ? i + batchSize
          : creatorIds.length;
      final batch = creatorIds.sublist(i, batchEnd);

      await Future.wait(
        batch.map(
          (creatorId) =>
              _loadCreatorProfile(creatorId, forceRefresh: forceRefresh),
        ),
      );
    }
  }

  /// Load like status and count for a route
  Future<void> _loadLikeStatus(int routeId, {bool forceRefresh = false}) async {
    if (_authService.accessToken == null) return;

    try {
      final results = await Future.wait([
        _routeRepository.checkIfLiked(
          routeId: routeId,
          accessToken: _authService.accessToken!,
          forceRefresh: forceRefresh,
        ),
        _routeRepository.getLikeCount(
          routeId: routeId,
          accessToken: _authService.accessToken,
          forceRefresh: forceRefresh,
        ),
      ]);

      final isLiked = results[0] as bool;
      final count = results[1] as int;

      if (mounted) {
        setState(() {
          _likedRoutes[routeId] = isLiked;
          _likeCounts[routeId] = count;
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Load creator profile for a route
  Future<void> _loadCreatorProfile(
    String creatorId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _creatorProfiles.containsKey(creatorId)) return;

    final accessToken = _authService.accessToken;
    if (accessToken == null) return;

    final result = await _profileRepository.getProfile(
      creatorId,
      accessToken: accessToken,
      forceRefresh: forceRefresh,
    );

    if (mounted && result.success && result.profile != null) {
      setState(() {
        _creatorProfiles[creatorId] = result.profile!;
      });
    }
  }

  /// Navigate to user profile
  void _navigateToUserProfile(String userId) {
    final profile = _creatorProfiles[userId];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            UserProfilePage(userId: userId, username: profile?.fullName),
      ),
    );
  }

  /// Toggle like status for a route
  Future<void> _toggleLike(RunRoute route) async {
    if (_authService.accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like routes')),
      );
      return;
    }

    final isCurrentlyLiked = _likedRoutes[route.id] ?? false;
    final currentCount = _likeCounts[route.id] ?? 0;

    // Optimistic update
    setState(() {
      _likedRoutes[route.id] = !isCurrentlyLiked;
      _likeCounts[route.id] = isCurrentlyLiked
          ? currentCount - 1
          : currentCount + 1;
    });

    try {
      if (isCurrentlyLiked) {
        await _routeRepository.unlikeRoute(
          routeId: route.id,
          accessToken: _authService.accessToken!,
        );
      } else {
        await _routeRepository.likeRoute(
          routeId: route.id,
          accessToken: _authService.accessToken!,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _likedRoutes[route.id] = isCurrentlyLiked;
          _likeCounts[route.id] = currentCount;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to update like')));
      }
    }
  }

  Future<void> _joinRoute(RunRoute route) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Joining route: ${route.title ?? "Untitled Route"}'),
        action: SnackBarAction(label: 'View', onPressed: () {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _matchedUsers.isEmpty) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Questionnaire banner (if not completed)
          if (_showQuestionnaireBanner && _hasSurveyBeenChecked)
            _buildQuestionnaireBanner(),

          // Instagram-style story circles
          _buildMatchedUsersCircles(),
          const SizedBox(height: 16),

          // Selected user info card (if a user is selected)
          if (_selectedMatchedUser != null) ...[
            _buildSelectedUserCard(_selectedMatchedUser!),
            const SizedBox(height: 16),
          ] else ...[
            // Info card when viewing all
            _buildInfoCard(),
            const SizedBox(height: 16),
          ],

          // Route cards
          if (_filteredRoutes.isEmpty)
            _buildEmptyRoutesState()
          else
            ..._filteredRoutes.map(
              (route) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildRouteCard(route),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMatchedUsersCircles() {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // "All" button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildAllButton(),
          ),
          // Matched user circles
          ..._matchedUsers.map(
            (user) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _buildUserCircle(user),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllButton() {
    final isSelected = _selectedUserId == null;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedUserId = null;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFF7ED321), Color(0xFF5DB30C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [Colors.grey[300]!, Colors.grey[400]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF5F5F5),
              ),
              child: const Center(
                child: Text('✨', style: TextStyle(fontSize: 24)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'All',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildUserCircle(MatchedUser user) {
    final isSelected = _selectedUserId == user.profile.userId;
    final profilePicUrl = ProfilePicHelper.getProfilePicUrl(
      user.profile.profilePic,
    );

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedUserId = user.profile.userId;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Match score badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Profile circle with gradient border
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF7ED321), Color(0xFF5DB30C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF64B5F6), Color(0xFF1976D2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                ),
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    image: profilePicUrl != null
                        ? DecorationImage(
                            image: NetworkImage(profilePicUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: profilePicUrl == null
                      ? Center(
                          child: Text(
                            user.displayName.isNotEmpty
                                ? user.displayName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? const Color(0xFF7ED321)
                                  : const Color(0xFF1976D2),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              // Match score badge
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getScoreColor(user.matchScore),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${user.matchScore}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 68,
            child: Text(
              user.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFF7ED321) : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return const Color(0xFF4CAF50);
    if (score >= 80) return const Color(0xFF8BC34A);
    if (score >= 70) return const Color(0xFFFFC107);
    return const Color(0xFFFF9800);
  }

  Widget _buildSelectedUserCard(MatchedUser user) {
    final profilePicUrl = ProfilePicHelper.getProfilePicUrl(
      user.profile.profilePic,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Profile picture
              GestureDetector(
                onTap: () => _navigateToUserProfile(user.profile.userId),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF7ED321),
                  backgroundImage: profilePicUrl != null
                      ? NetworkImage(profilePicUrl)
                      : null,
                  child: profilePicUrl == null
                      ? Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.profile.fullName.isNotEmpty
                          ? user.profile.fullName
                          : 'Runner',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${user.routes.length} ${user.routes.length == 1 ? 'route' : 'routes'} shared',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              // Match score
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getScoreColor(user.matchScore).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getScoreColor(
                      user.matchScore,
                    ).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 16,
                      color: _getScoreColor(user.matchScore),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${user.matchScore}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(user.matchScore),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F9FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat(
                  icon: Icons.speed,
                  value: _generateDummyPace(),
                  label: 'Avg Pace',
                ),
                Container(width: 1, height: 30, color: Colors.grey[300]),
                _buildMiniStat(
                  icon: Icons.calendar_today,
                  value: _generateDummyWeeklyDistance(),
                  label: 'Per Week',
                ),
                Container(width: 1, height: 30, color: Colors.grey[300]),
                _buildMiniStat(
                  icon: Icons.wb_sunny,
                  value: _generateDummyTimePreference(),
                  label: 'Prefers',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _navigateToUserProfile(user.profile.userId),
                  icon: const Icon(Icons.person_outline, size: 18),
                  label: const Text('View Profile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7ED321),
                    side: const BorderSide(color: Color(0xFF7ED321)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedUserId = null;
                    });
                  },
                  icon: const Icon(Icons.grid_view, size: 18),
                  label: const Text('View All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7ED321),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF7ED321)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  // Generate dummy stats for demo
  String _generateDummyPace() {
    final min = 4 + _random.nextInt(3);
    final sec = _random.nextInt(60).toString().padLeft(2, '0');
    return "$min'$sec\"/km";
  }

  String _generateDummyWeeklyDistance() {
    final km = 15 + _random.nextInt(40);
    return '$km km';
  }

  String _generateDummyTimePreference() {
    final preferences = ['Morning', 'Evening', 'Afternoon', 'Night'];
    return preferences[_random.nextInt(preferences.length)];
  }

  Widget _buildQuestionnaireBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7ED321), Color(0xFF5DB30C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7ED321).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete Your Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Answer a few questions to find better matches',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _openQuestionnaire,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF7ED321),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Take Quick Survey',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FCD9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF7ED321).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.people_outline,
                color: Color(0xFF7ED321),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Find Running Partners',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _matchedUsers.isEmpty
                ? 'No matches found yet. Check back later!'
                : 'Tap on a runner above to see their routes and match score. ${_matchedUsers.length} potential matches found!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _loadData(forceRefresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7ED321),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRoutesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _selectedUserId != null ? 'No Routes Yet' : 'No Routes Found',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedUserId != null
                  ? 'This runner hasn\'t shared any routes yet'
                  : 'Be the first to share a route!',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard(RunRoute route) {
    final creatorProfile = route.creatorId != null
        ? _creatorProfiles[route.creatorId]
        : null;
    final currentUserId = _authService.currentUser?.userId;
    final isOwnRoute = route.creatorId == currentUserId;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Creator header
          if (route.creatorId != null)
            InkWell(
              onTap: () => _navigateToUserProfile(route.creatorId!),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Builder(
                      builder: (context) {
                        final profilePicUrl = ProfilePicHelper.getProfilePicUrl(
                          creatorProfile?.profilePic,
                        );
                        return CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF7ED321),
                          backgroundImage: profilePicUrl != null
                              ? NetworkImage(profilePicUrl)
                              : null,
                          child: profilePicUrl == null
                              ? Text(
                                  _getCreatorInitial(creatorProfile),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _getCreatorName(creatorProfile, isOwnRoute),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isOwnRoute) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF7ED321,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'You',
                                    style: TextStyle(
                                      color: Color(0xFF7ED321),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            _getTimeAgo(route.createdAt),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),

          // Map preview
          ClipRRect(
            borderRadius: route.creatorId != null
                ? BorderRadius.zero
                : const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 200,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _calculateRouteCenter(route),
                  initialZoom: _calculateZoomLevel(route),
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
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(route.startPointLat, route.startPointLon),
                        width: 30,
                        height: 30,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      Marker(
                        point: LatLng(route.endPointLat, route.endPointLon),
                        width: 30,
                        height: 30,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.stop,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Route details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            route.title ?? 'Untitled Route',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (route.description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              route.description!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (route.difficulty != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getDifficultyColor(route.difficulty!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          route.difficulty!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Time ago and like button
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _getTimeAgo(route.createdAt),
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _toggleLike(route),
                      child: Row(
                        children: [
                          Icon(
                            (_likedRoutes[route.id] ?? false)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 22,
                            color: (_likedRoutes[route.id] ?? false)
                                ? Colors.red
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_likeCounts[route.id] ?? 0}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn(
                      icon: Icons.straighten,
                      value: route.formattedDistance,
                      label: 'Distance',
                    ),
                    _buildStatColumn(
                      icon: Icons.timer,
                      value: route.formattedDuration,
                      label: 'Duration',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Join button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _joinRoute(route),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7ED321),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_run),
                        SizedBox(width: 8),
                        Text(
                          'Join This Route',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCreatorInitial(UserProfile? profile) {
    if (profile != null && profile.fullName.isNotEmpty) {
      return profile.fullName[0].toUpperCase();
    }
    return '?';
  }

  String _getCreatorName(UserProfile? profile, bool isOwnRoute) {
    if (isOwnRoute) {
      if (profile != null && profile.fullName.isNotEmpty) {
        return profile.fullName;
      }
      return _authService.currentUser?.username ?? 'You';
    }
    if (profile != null && profile.fullName.isNotEmpty) {
      return profile.fullName;
    }
    return 'Runner';
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.grey[700]),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
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

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  LatLng _calculateRouteCenter(RunRoute route) {
    if (route.points.isEmpty) {
      return LatLng(
        (route.startPointLat + route.endPointLat) / 2,
        (route.startPointLon + route.endPointLon) / 2,
      );
    }

    double minLat = route.points.first.latitude;
    double maxLat = route.points.first.latitude;
    double minLon = route.points.first.longitude;
    double maxLon = route.points.first.longitude;

    for (var point in route.points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    return LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
  }

  double _calculateZoomLevel(RunRoute route) {
    if (route.points.isEmpty) {
      final latDiff = (route.startPointLat - route.endPointLat).abs();
      final lonDiff = (route.startPointLon - route.endPointLon).abs();
      final maxDiff = latDiff > lonDiff ? latDiff : lonDiff;

      if (maxDiff < 0.005) return 16.0;
      if (maxDiff < 0.01) return 15.0;
      if (maxDiff < 0.02) return 14.0;
      if (maxDiff < 0.05) return 13.0;
      if (maxDiff < 0.1) return 12.0;
      if (maxDiff < 0.2) return 11.0;
      return 10.0;
    }

    double minLat = route.points.first.latitude;
    double maxLat = route.points.first.latitude;
    double minLon = route.points.first.longitude;
    double maxLon = route.points.first.longitude;

    for (var point in route.points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    final latDiff = maxLat - minLat;
    final lonDiff = maxLon - minLon;
    final maxDiff = latDiff > lonDiff ? latDiff : lonDiff;

    if (maxDiff < 0.005) return 15.0;
    if (maxDiff < 0.01) return 14.0;
    if (maxDiff < 0.02) return 13.0;
    if (maxDiff < 0.05) return 12.0;
    if (maxDiff < 0.1) return 11.0;
    if (maxDiff < 0.2) return 10.0;
    return 9.0;
  }
}
