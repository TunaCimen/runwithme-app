import 'package:flutter/material.dart';
import '../../../../core/utils/profile_pic_helper.dart';
import '../../data/models/comment_dto.dart';

/// Tile widget for displaying a comment
class CommentTile extends StatelessWidget {
  final CommentDto comment;
  final bool isOwnComment;
  final VoidCallback? onDelete;
  final VoidCallback? onAuthorTap;

  const CommentTile({
    super.key,
    required this.comment,
    this.isOwnComment = false,
    this.onDelete,
    this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    final profilePicUrl = ProfilePicHelper.getProfilePicUrl(comment.authorProfilePic);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onAuthorTap,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF7ED321).withValues(alpha: 0.2),
              backgroundImage: profilePicUrl != null
                  ? NetworkImage(profilePicUrl)
                  : null,
              child: profilePicUrl == null
                  ? Text(
                      comment.authorDisplayName.isNotEmpty
                          ? comment.authorDisplayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Color(0xFF7ED321),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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
                Row(
                  children: [
                    GestureDetector(
                      onTap: onAuthorTap,
                      child: Text(
                        comment.authorDisplayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.timeAgo,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.commentText,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (isOwnComment)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[400]),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'delete') {
                  onDelete?.call();
                }
              },
            ),
        ],
      ),
    );
  }
}
