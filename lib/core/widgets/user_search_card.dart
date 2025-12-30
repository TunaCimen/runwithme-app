import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../utils/profile_pic_helper.dart';
import 'highlighted_text.dart';

/// Enum for friendship status display
enum UserFriendshipStatus {
  none,
  friends,
  pendingSent,
  pendingReceived,
}

/// A compact user card for search results
class UserSearchCard extends StatelessWidget {
  final UserProfile profile;
  final String? searchQuery;
  final UserFriendshipStatus friendshipStatus;
  final VoidCallback? onTap;
  final VoidCallback? onSendRequest;
  final VoidCallback? onAcceptRequest;
  final bool isLoading;

  const UserSearchCard({
    super.key,
    required this.profile,
    this.searchQuery,
    this.friendshipStatus = UserFriendshipStatus.none,
    this.onTap,
    this.onSendRequest,
    this.onAcceptRequest,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final profilePicUrl = ProfilePicHelper.getProfilePicUrl(profile.profilePic);
    final displayName = profile.displayName;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Avatar
              GestureDetector(
                onTap: onTap,
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF7ED321),
                  backgroundImage:
                      profilePicUrl != null ? NetworkImage(profilePicUrl) : null,
                  child: profilePicUrl == null
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              // Name and info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (searchQuery != null && searchQuery!.isNotEmpty)
                      HighlightedText(
                        text: displayName,
                        searchQuery: searchQuery!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (profile.expertLevel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        profile.expertLevel!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Action button based on friendship status
              _buildActionButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF7ED321),
        ),
      );
    }

    switch (friendshipStatus) {
      case UserFriendshipStatus.friends:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF7ED321).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 16,
                color: Color(0xFF7ED321),
              ),
              SizedBox(width: 4),
              Text(
                'Friends',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF7ED321),
                ),
              ),
            ],
          ),
        );

      case UserFriendshipStatus.pendingSent:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'Pending',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        );

      case UserFriendshipStatus.pendingReceived:
        return ElevatedButton(
          onPressed: onAcceptRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7ED321),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Accept',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        );

      case UserFriendshipStatus.none:
        return ElevatedButton(
          onPressed: onSendRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7ED321),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_add, size: 16),
              SizedBox(width: 4),
              Text(
                'Add',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
    }
  }
}
