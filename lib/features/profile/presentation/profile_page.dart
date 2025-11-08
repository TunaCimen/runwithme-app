import 'package:flutter/material.dart';
import '../../auth/data/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var currentUser = _authService.currentUser;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with profile header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  _showSettingsSheet();
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primaryContainer,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Text(
                          currentUser?.fullName[0].toUpperCase() ?? 'U',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        currentUser?.fullName ?? 'User',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '@${currentUser?.username ?? 'username'}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Stats row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatColumn('Runs', '42'),
                          _buildStatColumn('Distance', '215 km'),
                          _buildStatColumn('Streak', '7 days'),
                        ],
                      ),
                    ],
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
                  Tab(text: 'Runs'),
                  Tab(text: 'Stats'),
                  Tab(text: 'Awards'),
                ],
              ),
            ),
          ),

          // Tab content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRunsTab(),
                _buildStatsTab(),
                _buildAwardsTab(),
              ],
            ),
          ),
        ],
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
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildRunsTab() {
    var runs = [
      RunRecord(
        date: '2024-01-15',
        routeName: 'Morning Run',
        distance: 5.2,
        duration: '28:36',
        pace: '5:30',
      ),
      RunRecord(
        date: '2024-01-14',
        routeName: 'Evening Jog',
        distance: 3.5,
        duration: '21:00',
        pace: '6:00',
      ),
      RunRecord(
        date: '2024-01-13',
        routeName: 'Trail Run',
        distance: 8.0,
        duration: '52:00',
        pace: '6:30',
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: runs.length,
      itemBuilder: (context, index) {
        return _buildRunCard(runs[index]);
      },
    );
  }

  Widget _buildRunCard(RunRecord run) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  run.routeName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  run.date,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildRunStat(Icons.route, '${run.distance} km'),
                _buildRunStat(Icons.timer, run.duration),
                _buildRunStat(Icons.speed, '${run.pace} /km'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRunStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildStatsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatCard(
          'This Week',
          [
            StatItem('Total Distance', '25.3 km'),
            StatItem('Total Runs', '5'),
            StatItem('Avg Pace', '5:45 /km'),
            StatItem('Total Time', '2h 25m'),
          ],
        ),
        const SizedBox(height: 16),
        _buildStatCard(
          'This Month',
          [
            StatItem('Total Distance', '102.5 km'),
            StatItem('Total Runs', '18'),
            StatItem('Avg Pace', '5:52 /km'),
            StatItem('Total Time', '10h 15m'),
          ],
        ),
        const SizedBox(height: 16),
        _buildStatCard(
          'All Time',
          [
            StatItem('Total Distance', '1,234 km'),
            StatItem('Total Runs', '156'),
            StatItem('Best Pace', '4:30 /km'),
            StatItem('Longest Run', '21.1 km'),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, List<StatItem> items) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    item.value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildAwardsTab() {
    var awards = [
      Award(
        name: 'First Run',
        description: 'Complete your first run',
        icon: Icons.emoji_events,
        unlocked: true,
      ),
      Award(
        name: '100km Club',
        description: 'Run a total of 100km',
        icon: Icons.military_tech,
        unlocked: true,
      ),
      Award(
        name: 'Early Bird',
        description: 'Complete 10 morning runs',
        icon: Icons.wb_sunny,
        unlocked: true,
      ),
      Award(
        name: 'Marathon Ready',
        description: 'Complete a 42km run',
        icon: Icons.workspace_premium,
        unlocked: false,
      ),
      Award(
        name: 'Speed Demon',
        description: 'Achieve sub-4:00 /km pace',
        icon: Icons.bolt,
        unlocked: false,
      ),
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: awards.length,
      itemBuilder: (context, index) {
        return _buildAwardCard(awards[index]);
      },
    );
  }

  Widget _buildAwardCard(Award award) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: award.unlocked
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.amber[100]!,
                    Colors.amber[50]!,
                  ],
                )
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              award.icon,
              size: 48,
              color: award.unlocked ? Colors.amber[700] : Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              award.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: award.unlocked ? Colors.black87 : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              award.description,
              style: TextStyle(
                fontSize: 12,
                color: award.unlocked ? Colors.black54 : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Profile'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Settings'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notifications'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  _handleLogout();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
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

// Models
class RunRecord {
  final String date;
  final String routeName;
  final double distance;
  final String duration;
  final String pace;

  RunRecord({
    required this.date,
    required this.routeName,
    required this.distance,
    required this.duration,
    required this.pace,
  });
}

class StatItem {
  final String label;
  final String value;

  StatItem(this.label, this.value);
}

class Award {
  final String name;
  final String description;
  final IconData icon;
  final bool unlocked;

  Award({
    required this.name,
    required this.description,
    required this.icon,
    required this.unlocked,
  });
}
