import 'package:flutter/material.dart';

/// Reusable tile for displaying a friend/user
class FriendListTile extends StatelessWidget {
  final String displayName;
  final String? username;
  final String? profilePicUrl;
  final String? subtitle;
  final VoidCallback? onTap;
  final List<Widget>? trailing;

  const FriendListTile({
    super.key,
    required this.displayName,
    this.username,
    this.profilePicUrl,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFF7ED321).withValues(alpha: 0.2),
        backgroundImage: profilePicUrl != null ? NetworkImage(profilePicUrl!) : null,
        child: profilePicUrl == null
            ? Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Color(0xFF7ED321),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              )
            : null,
      ),
      title: Text(
        displayName,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null || username != null
          ? Text(
              subtitle ?? '@$username',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            )
          : null,
      trailing: trailing != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: trailing!,
            )
          : null,
    );
  }
}
