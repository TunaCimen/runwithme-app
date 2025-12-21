import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/models/run_session.dart';
import '../../../core/models/user_statistics.dart';
import '../../auth/data/auth_service.dart';
import '../../feed/data/feed_post_enricher.dart';
import '../data/profile_repository.dart';
import '../../map/data/route_repository.dart';
import '../../friends/presentation/screens/friends_screen.dart';
import '../../run/presentation/live_tracking_page.dart';
import '../../run/data/run_repository.dart';
import '../../run/presentation/widgets/run_session_card.dart';
import '../../feed/data/feed_repository.dart';
import '../../feed/data/models/feed_post_dto.dart';
import '../../feed/presentation/widgets/feed_post_card.dart';
import '../../feed/presentation/screens/post_detail_screen.dart';
import '../../survey/data/survey_repository.dart';
import '../../survey/presentation/questionnaire_screen.dart';
import 'edit_profile_page.dart';
import 'saved_routes_tab.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _authService = AuthService();
  final _profileRepository = ProfileRepository();
  final _routeRepository = RouteRepository();
  final _feedRepository = FeedRepository();
  final _runRepository = RunRepository();
  final _postEnricher = FeedPostEnricher();

  UserProfile? _userProfile;
  bool _isLoading = true;

  // User's posts state
  List<FeedPostDto> _userPosts = [];
  bool _postsLoading = false;
  bool _postsHasMore = true;
  int _postsPage = 0;

  // User's runs state
  List<RunSession> _userRuns = [];
  bool _runsLoading = false;
  bool _runsHasMore = true;
  int _runsPage = 0;

  // Stats
  int _totalRuns = 0;
  double _totalDistanceKm = 0;

  // User statistics from API for different periods
  UserStatistics? _dailyStats; // 1 day
  UserStatistics? _weeklyStats; // 7 days
  UserStatistics? _monthlyStats; // 30 days
  UserStatistics? _allTimeStats; // no days param (defaults to all)
  bool _statisticsLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    final token = _authService.accessToken;
    if (token != null) {
      _feedRepository.setAuthToken(token);
    }

    _loadProfile();
    _loadUserPosts(refresh: true);
    _loadUserRuns(refresh: true);
    _loadUserStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = _authService.currentUser;
    final accessToken = _authService.accessToken;

    if (user == null || accessToken == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    final result = await _profileRepository.getProfile(
      user.userId,
      accessToken: accessToken,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success) {
          _userProfile = result.profile;
        }
      });
    }
  }

  Future<void> _loadUserPosts({bool refresh = false}) async {
    final user = _authService.currentUser;
    final accessToken = _authService.accessToken;
    if (user == null || _postsLoading) return;

    if (refresh) {
      _postsPage = 0;
      _postsHasMore = true;
    }

    if (!_postsHasMore) return;

    setState(() {
      _postsLoading = true;
    });

    final result = await _feedRepository.getUserPosts(
      user.userId,
      page: _postsPage,
      size: 10,
    );

    if (mounted && result.success && result.data != null) {
      // Enrich posts with route/run data from API
      final enrichedWithRouteRun = await _postEnricher.enrichPosts(
        result.data!.content,
        accessToken: accessToken,
      );

      // Add author info
      final displayName = _userProfile?.fullName.isNotEmpty == true
          ? _userProfile!.fullName
          : (user.username.isNotEmpty
                ? user.username
                : user.email.split('@').first);
      final enrichedPosts = enrichedWithRouteRun.map((post) {
        return post.copyWith(
          authorUsername: displayName,
          authorFirstName: _userProfile?.firstName ?? displayName,
          authorLastName: _userProfile?.lastName,
          authorProfilePic: _userProfile?.profilePic,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _postsLoading = false;
          if (refresh) {
            _userPosts = enrichedPosts;
          } else {
            _userPosts = [..._userPosts, ...enrichedPosts];
          }
          _postsHasMore = !result.data!.last;
          _postsPage++;
        });
      }
    } else if (mounted) {
      setState(() {
        _postsLoading = false;
      });
    }
  }

  Future<void> _loadUserRuns({bool refresh = false}) async {
    final user = _authService.currentUser;
    final accessToken = _authService.accessToken;
    if (user == null || _runsLoading) return;

    if (refresh) {
      _runsPage = 0;
      _runsHasMore = true;
    }

    if (!_runsHasMore) return;

    setState(() {
      _runsLoading = true;
    });

    final result = await _runRepository.getUserRuns(
      user.userId,
      accessToken: accessToken,
      page: _runsPage,
      size: 10,
      forceRefresh: refresh,
    );

    if (mounted && result.success && result.data != null) {
      // Fetch full details for each run to get points
      final runsWithPoints = <RunSession>[];
      for (final run in result.data!) {
        // Check if run already has points
        if (run.points.isNotEmpty) {
          runsWithPoints.add(run);
        } else {
          // Fetch full run details to get points
          final detailResult = await _runRepository.getRunSession(
            run.id,
            accessToken: accessToken,
          );
          if (detailResult.success && detailResult.data != null) {
            runsWithPoints.add(detailResult.data!);
          } else {
            // Use original run if fetch fails
            runsWithPoints.add(run);
          }
        }
      }

      if (mounted) {
        setState(() {
          _runsLoading = false;
          if (refresh) {
            _userRuns = runsWithPoints;
          } else {
            _userRuns = [..._userRuns, ...runsWithPoints];
          }
          _runsHasMore = result.data!.length >= 10;
          _runsPage++;

          // Calculate stats
          _totalRuns = _userRuns.length;
          _totalDistanceKm = _userRuns.fold(
            0.0,
            (sum, run) => sum + run.distanceKm,
          );
        });
      }
    } else if (mounted) {
      setState(() {
        _runsLoading = false;
      });
    }
  }

  Future<void> _loadUserStatistics() async {
    final user = _authService.currentUser;
    final accessToken = _authService.accessToken;
    if (user == null || accessToken == null) return;

    setState(() {
      _statisticsLoading = true;
    });

    // Fetch all periods in parallel
    final results = await Future.wait([
      _profileRepository.getUserStatistics(
        user.userId,
        accessToken: accessToken,
        days: 1,
      ),
      _profileRepository.getUserStatistics(
        user.userId,
        accessToken: accessToken,
        days: 7,
      ),
      _profileRepository.getUserStatistics(
        user.userId,
        accessToken: accessToken,
        days: 30,
      ),
      _profileRepository.getUserStatistics(
        user.userId,
        accessToken: accessToken,
      ), // all time (no days param)
    ]);

    if (mounted) {
      setState(() {
        _statisticsLoading = false;
        if (results[0].success) _dailyStats = results[0].statistics;
        if (results[1].success) _weeklyStats = results[1].statistics;
        if (results[2].success) _monthlyStats = results[2].statistics;
        if (results[3].success) _allTimeStats = results[3].statistics;
      });
    }
  }

  /// Get full URL for profile picture
  String? _getProfilePicUrl() {
    final profilePic = _userProfile?.profilePic;
    if (profilePic == null || profilePic.isEmpty) return null;

    // If it's already a full URL, return as is
    if (profilePic.startsWith('http://') || profilePic.startsWith('https://')) {
      return profilePic;
    }

    // Otherwise, construct the URL
    return _profileRepository.getProfilePictureUrl(profilePic);
  }

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push<UserProfile>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(existingProfile: _userProfile),
      ),
    );

    if (result != null) {
      setState(() {
        _userProfile = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view your profile')),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with profile header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.people_outline),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FriendsScreen(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: _showSettingsSheet,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF7ED321), Color(0xFF9AE64A)],
                  ),
                ),
                child: SafeArea(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 10),
                              CircleAvatar(
                                radius: 45,
                                backgroundColor: Colors.white,
                                backgroundImage: _getProfilePicUrl() != null
                                    ? NetworkImage(_getProfilePicUrl()!)
                                    : null,
                                onBackgroundImageError:
                                    _getProfilePicUrl() != null
                                    ? (exception, stackTrace) {
                                        debugPrint(
                                          '[ProfilePage] Error loading profile pic: $exception',
                                        );
                                      }
                                    : null,
                                child: _getProfilePicUrl() == null
                                    ? Text(
                                        _userProfile?.firstName?.isNotEmpty ==
                                                true
                                            ? _userProfile!.firstName![0]
                                                  .toUpperCase()
                                            : (currentUser.username.isNotEmpty
                                                  ? currentUser.username[0]
                                                        .toUpperCase()
                                                  : currentUser.email[0]
                                                        .toUpperCase()),
                                        style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF7ED321),
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _userProfile?.fullName.isNotEmpty == true
                                    ? _userProfile!.fullName
                                    : (currentUser.username.isNotEmpty
                                          ? currentUser.username
                                          : currentUser.email.split('@').first),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                currentUser.username.isNotEmpty
                                    ? '@${currentUser.username}'
                                    : currentUser.email,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              if (_userProfile?.expertLevel != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _userProfile!.expertLevel!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              // Stats row - show all-time stats
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStatColumn(
                                    'Runs',
                                    '${_allTimeStats?.allTimeTotalRuns ?? _totalRuns}',
                                  ),
                                  _buildStatColumn(
                                    'Distance',
                                    '${_allTimeStats?.totalDistanceKm.toStringAsFixed(1) ?? _totalDistanceKm.toStringAsFixed(1)} km',
                                  ),
                                  _buildStatColumn(
                                    'Avg Pace',
                                    _allTimeStats?.averagePace ?? '--',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),

          // Tab bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.directions_run), text: 'Runs'),
                  Tab(icon: Icon(Icons.article), text: 'Posts'),
                  Tab(icon: Icon(Icons.bar_chart), text: 'Stats'),
                  Tab(icon: Icon(Icons.favorite), text: 'Saved'),
                ],
              ),
            ),
          ),

          // Tab content
          SliverFillRemaining(
            child: _userProfile == null && !_isLoading
                ? _buildNoProfileState()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRunsTab(),
                      _buildPostsTab(),
                      _buildStatsTab(),
                      SavedRoutesTab(
                        authService: _authService,
                        routeRepository: _routeRepository,
                        runRepository: _runRepository,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoProfileState() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            Icon(Icons.person_add_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            const Text(
              'Complete Your Profile',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Add your personal information to get started with RunWithMe',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _navigateToEditProfile,
              icon: const Icon(Icons.edit),
              label: const Text('Create Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7ED321),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildRunsTab() {
    if (_runsLoading && _userRuns.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userRuns.isEmpty) {
      return _buildEmptyState(
        icon: Icons.directions_run,
        title: 'No Runs Yet',
        message: 'Start tracking your runs to see them here',
        actionLabel: 'Start a Run',
        onAction: () async {
          final result = await Navigator.push<RunSession>(
            context,
            MaterialPageRoute(builder: (context) => const LiveTrackingPage()),
          );
          if (result != null) {
            // Reload runs after completing a run
            _loadUserRuns(refresh: true);
          }
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadUserRuns(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _userRuns.length + 1 + (_runsHasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Start a Run button at top
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push<RunSession>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LiveTrackingPage(),
                    ),
                  );
                  if (result != null) {
                    _loadUserRuns(refresh: true);
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start a New Run'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7ED321),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            );
          }

          // Loading indicator at bottom
          if (index > _userRuns.length) {
            _loadUserRuns();
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final run = _userRuns[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: RunSessionCard(
              session: run,
              showDeleteButton: true,
              onTap: () => _showRunDetails(run),
              onDelete: () => _confirmDeleteRun(run),
            ),
          );
        },
      ),
    );
  }

  void _showRunDetails(RunSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _RunDetailsSheet(
          session: session,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _confirmDeleteRun(RunSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Run?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteRun(session);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRun(RunSession session) async {
    final accessToken = _authService.accessToken;
    final result = await _runRepository.deleteRunSession(
      session.id,
      accessToken: accessToken,
    );

    if (result.success) {
      setState(() {
        _userRuns.removeWhere((r) => r.id == session.id);
        _totalRuns = _userRuns.length;
        _totalDistanceKm = _userRuns.fold(
          0.0,
          (sum, run) => sum + run.distanceKm,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Run deleted')));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Failed to delete run')),
        );
      }
    }
  }

  Widget _buildStatsTab() {
    if (_statisticsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasAnyData =
        (_dailyStats?.hasData ?? false) ||
        (_weeklyStats?.hasData ?? false) ||
        (_monthlyStats?.hasData ?? false) ||
        (_allTimeStats?.hasData ?? false);

    if (!hasAnyData) {
      return _buildEmptyState(
        icon: Icons.bar_chart,
        title: 'No Statistics Yet',
        message: 'Complete your first run to see your stats',
        actionLabel: 'Start a Run',
        onAction: () async {
          final result = await Navigator.push<RunSession>(
            context,
            MaterialPageRoute(builder: (context) => const LiveTrackingPage()),
          );
          if (result != null) {
            _loadUserRuns(refresh: true);
            _loadUserStatistics();
          }
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadUserStatistics();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Activity
            _buildPeriodSection(
              title: 'Today',
              icon: Icons.today,
              color: const Color(0xFF4CAF50),
              stats: _dailyStats,
            ),
            const SizedBox(height: 20),

            // Weekly Activity
            _buildPeriodSection(
              title: 'This Week',
              icon: Icons.date_range,
              color: const Color(0xFF2196F3),
              stats: _weeklyStats,
            ),
            const SizedBox(height: 20),

            // Monthly Activity
            _buildPeriodSection(
              title: 'This Month',
              icon: Icons.calendar_month,
              color: const Color(0xFFFF9800),
              stats: _monthlyStats,
            ),
            const SizedBox(height: 20),

            // All-time Stats
            _buildAllTimeSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSection({
    required String title,
    required IconData icon,
    required Color color,
    required UserStatistics? stats,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats grid
          if (stats == null || stats.totalRuns == 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No activity',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildMiniStatCard(
                    label: 'Runs',
                    value: '${stats.totalRuns}',
                    icon: Icons.directions_run,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMiniStatCard(
                    label: 'Distance',
                    value: '${stats.totalDistanceKm.toStringAsFixed(1)} km',
                    icon: Icons.straighten,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMiniStatCard(
                    label: 'Avg Pace',
                    value: stats.averagePace ?? '--',
                    icon: Icons.speed,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF7ED321), size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAllTimeSection() {
    final stats = _allTimeStats;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7ED321), Color(0xFF9AE64A)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7ED321).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'All Time',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // All-time stats
          Row(
            children: [
              Expanded(
                child: _buildAllTimeStatItem(
                  label: 'Total Runs',
                  value: '${stats?.allTimeTotalRuns ?? 0}',
                  icon: Icons.directions_run,
                ),
              ),
              Expanded(
                child: _buildAllTimeStatItem(
                  label: 'Total Distance',
                  value:
                      '${stats?.totalDistanceKm.toStringAsFixed(1) ?? '0.0'} km',
                  icon: Icons.straighten,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAllTimeStatItem(
                  label: 'Avg Pace',
                  value: stats?.averagePace ?? '--',
                  icon: Icons.speed,
                ),
              ),
              Expanded(
                child: _buildAllTimeStatItem(
                  label: 'Avg Distance/Run',
                  value:
                      '${stats?.averageDistancePerRunKm.toStringAsFixed(2) ?? '0.00'} km',
                  icon: Icons.moving,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllTimeStatItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPostsTab() {
    if (_postsLoading && _userPosts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userPosts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.article_outlined,
        title: 'No Posts Yet',
        message: 'Share your runs and routes with your friends',
        actionLabel: 'Create Post',
        onAction: () {
          Navigator.pushNamed(context, '/create-post');
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadUserPosts(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _userPosts.length + (_postsHasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _userPosts.length) {
            _loadUserPosts();
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final post = _userPosts[index];
          return FeedPostCard(
            post: post,
            onTap: () => _navigateToPostDetail(post),
            onLike: () {},
            onComment: () => _navigateToPostDetail(post),
          );
        },
      ),
    );
  }

  void _navigateToPostDetail(FeedPostDto post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PostDetailScreen(postId: post.id, initialPost: post),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7ED321),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        return SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToEditProfile();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('Friends'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FriendsScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Running Preferences'),
                  subtitle: const Text('Match settings & schedule'),
                  onTap: () {
                    Navigator.pop(context);
                    _openRunningPreferences();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Privacy settings coming soon'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notification settings coming soon'),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: _handleLogout,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openRunningPreferences() async {
    final accessToken = _authService.accessToken;
    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to access preferences')),
      );
      return;
    }

    // Load existing survey response
    final surveyRepo = SurveyRepository.instance;
    final result = await surveyRepo.getMySurveyResponse(
      accessToken: accessToken,
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            QuestionnaireScreen(existingResponse: result.data, isModal: false),
      ),
    );
  }

  void _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pop(context); // Close settings sheet
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }
}

// Sliver tab bar delegate for pinned tabs
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

/// Bottom sheet showing run details
class _RunDetailsSheet extends StatelessWidget {
  final RunSession session;
  final ScrollController scrollController;

  const _RunDetailsSheet({
    required this.session,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            _getRunTitle(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _formatFullDate(session.startedAt),
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // Main stats
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FCD9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMainStat(
                      'Distance',
                      session.formattedDistance,
                      Icons.straighten,
                    ),
                    _buildMainStat(
                      'Duration',
                      session.formattedDuration,
                      Icons.timer,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMainStat(
                      'Avg Pace',
                      session.formattedPace,
                      Icons.speed,
                    ),
                    if (session.elevationGainM != null &&
                        session.elevationGainM! > 0)
                      _buildMainStat(
                        'Elevation',
                        '${session.elevationGainM!.toInt()} m',
                        Icons.trending_up,
                      )
                    else
                      _buildMainStat(
                        'Points',
                        '${session.points.length}',
                        Icons.location_on,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Additional info
          if (session.endedAt != null) ...[
            _buildInfoRow('Started', _formatTime(session.startedAt)),
            _buildInfoRow('Ended', _formatTime(session.endedAt!)),
          ],
          if (session.isPublic) _buildInfoRow('Visibility', 'Public'),
          const SizedBox(height: 24),

          // Map preview if we have points
          if (session.points.length > 1) ...[
            const Text(
              'Route',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildMapPreview(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF7ED321), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMapPreview() {
    if (session.points.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No route data available',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // Convert run points to LatLng list
    final points = session.points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    // Calculate center and zoom
    final center = _calculateCenter(points);
    final zoom = _calculateZoom(points);

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.runwithme_app',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: points,
              strokeWidth: 4.0,
              color: const Color(0xFF7ED321),
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            // Start marker
            Marker(
              point: points.first,
              width: 24,
              height: 24,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
            // End marker
            if (points.length > 1)
              Marker(
                point: points.last,
                width: 24,
                height: 24,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.stop, color: Colors.white, size: 14),
                ),
              ),
          ],
        ),
      ],
    );
  }

  LatLng _calculateCenter(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    if (points.length == 1) return points.first;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLon = points.first.longitude;
    double maxLon = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    return LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
  }

  double _calculateZoom(List<LatLng> points) {
    if (points.isEmpty || points.length == 1) return 15.0;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLon = points.first.longitude;
    double maxLon = points.first.longitude;

    for (var point in points) {
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

  String _getRunTitle() {
    final hour = session.startedAt.hour;
    if (hour >= 5 && hour < 12) {
      return 'Morning Run';
    } else if (hour >= 12 && hour < 17) {
      return 'Afternoon Run';
    } else if (hour >= 17 && hour < 21) {
      return 'Evening Run';
    } else {
      return 'Night Run';
    }
  }

  String _formatFullDate(DateTime dateTime) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${days[dateTime.weekday - 1]}, ${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:$minute $period';
  }
}
