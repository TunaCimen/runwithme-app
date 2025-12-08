import 'package:flutter/material.dart';
import '../../../auth/data/auth_service.dart';
import '../../data/models/feed_post_dto.dart';
import '../../providers/feed_provider.dart';
import '../widgets/feed_post_card.dart';
import '../widgets/comment_tile.dart';

/// Screen for viewing post details and comments
class PostDetailScreen extends StatefulWidget {
  final int postId;
  final FeedPostDto? initialPost;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.initialPost,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late FeedProvider _feedProvider;
  final _authService = AuthService();
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  FeedPostDto? _post;

  @override
  void initState() {
    super.initState();
    _feedProvider = FeedProvider();
    _post = widget.initialPost;

    final token = _authService.accessToken;
    if (token != null) {
      _feedProvider.setAuthToken(token);
    }

    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _feedProvider.loadMoreComments(widget.postId);
    }
  }

  Future<void> _loadData() async {
    if (_post == null) {
      final post = await _feedProvider.loadPost(widget.postId);
      if (mounted && post != null) {
        setState(() => _post = post);
      }
    }
    await _feedProvider.loadComments(widget.postId, refresh: true);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Post',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_post != null && _post!.authorId == _authService.currentUser?.userId)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black87),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete Post', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'delete') {
                  _deletePost();
                }
              },
            ),
        ],
      ),
      body: _post == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FeedPostCard(
                            post: _post!,
                            onLike: () => _toggleLike(),
                          ),
                          _buildCommentsSection(),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildCommentInput(),
              ],
            ),
    );
  }

  Widget _buildCommentsSection() {
    final comments = _feedProvider.getCommentsForPost(widget.postId);
    final isLoading = _feedProvider.isCommentsLoading(widget.postId);

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Comments (${_post?.commentsCount ?? 0})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (comments.isEmpty && !isLoading)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'No comments yet',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Be the first to comment!',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= comments.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final comment = comments[index];
                final isOwnComment =
                    comment.userId == _authService.currentUser?.userId;

                return CommentTile(
                  comment: comment,
                  isOwnComment: isOwnComment,
                  onDelete: () => _deleteComment(comment.id),
                  onAuthorTap: () => _navigateToProfile(comment.userId),
                );
              },
            ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 12),
          ListenableBuilder(
            listenable: _feedProvider,
            builder: (context, _) {
              return IconButton(
                onPressed: _feedProvider.addingComment ? null : _addComment,
                icon: _feedProvider.addingComment
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send, color: Color(0xFF7ED321)),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLike() async {
    if (_post == null) return;
    await _feedProvider.toggleLike(_post!.id);

    // Update local post state
    setState(() {
      _post = _post!.copyWith(
        isLikedByCurrentUser: !_post!.isLikedByCurrentUser,
        likesCount: _post!.isLikedByCurrentUser
            ? _post!.likesCount - 1
            : _post!.likesCount + 1,
      );
    });
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final result = await _feedProvider.addComment(widget.postId, text);
    if (result.success) {
      _commentController.clear();
      setState(() {
        _post = _post?.copyWith(commentsCount: (_post?.commentsCount ?? 0) + 1);
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Failed to add comment')),
      );
    }
  }

  Future<void> _deleteComment(int commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _feedProvider.deleteComment(widget.postId, commentId);
      if (result.success && mounted) {
        setState(() {
          _post = _post?.copyWith(commentsCount: (_post?.commentsCount ?? 1) - 1);
        });
      }
    }
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _feedProvider.deletePost(widget.postId);
      if (mounted) {
        if (result.success) {
          Navigator.pop(context, true); // Return true to indicate deletion
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? 'Failed to delete post')),
          );
        }
      }
    }
  }

  void _navigateToProfile(String userId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Navigate to profile: $userId')),
    );
  }
}
