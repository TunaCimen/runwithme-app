import 'package:flutter/material.dart';

class MatchesTab extends StatelessWidget {
  const MatchesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FCD9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF7ED321).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Find Your Running Partner',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We\'ve found 4 runners with similar pace, distance, and schedule nearby',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Match cards
        _buildMatchCard(
          name: 'Alex Martinez',
          location: 'Central Park, NYC',
          matchPercentage: 94,
          matchReason: 'Similar pace & location',
          avgPace: '5\'25"',
          perWeek: '30 km',
          prefers: 'Morning',
        ),
        const SizedBox(height: 16),
        _buildMatchCard(
          name: 'Jordan Kim',
          location: 'Brooklyn Bridge Park',
          matchPercentage: 89,
          matchReason: 'Same running goals',
          avgPace: '5\'40"',
          perWeek: '25 km',
          prefers: 'Evening',
        ),
        const SizedBox(height: 16),
        _buildMatchCard(
          name: 'Emma Wilson',
          location: 'Prospect Park',
          matchPercentage: 86,
          matchReason: 'Similar schedule',
          avgPace: '6\'10"',
          perWeek: '28 km',
          prefers: 'Morning',
        ),
      ],
    );
  }

  Widget _buildMatchCard({
    required String name,
    required String location,
    required int matchPercentage,
    required String matchReason,
    required String avgPace,
    required String perWeek,
    required String prefers,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF7ED321).withValues(alpha: 0.2),
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF7ED321),
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Name and location
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Match percentage badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7ED321),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.flash_on,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$matchPercentage% Match',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Match reason
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                matchReason,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  icon: Icons.speed,
                  value: avgPace,
                  label: 'Avg Pace',
                ),
                _buildStatColumn(
                  icon: Icons.show_chart,
                  value: perWeek,
                  label: 'Per Week',
                ),
                _buildStatColumn(
                  icon: Icons.schedule,
                  value: prefers,
                  label: 'Prefers',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Connect button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7ED321),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Connect & Run Together',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
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
        Icon(icon, size: 18, color: Colors.grey[700]),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
