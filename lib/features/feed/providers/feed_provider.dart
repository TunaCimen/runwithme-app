import 'package:flutter/foundation.dart';
import '../data/feed_repository.dart';
import '../data/models/feed_post_dto.dart';
import '../data/models/comment_dto.dart';
import '../data/models/create_post_dto.dart';

/// Provider for managing feed state
class FeedProvider extends ChangeNotifier {
  final FeedRepository _repository;

  // Feed state
  List<FeedPostDto> _feedPosts = [];
  bool _feedLoading = false;
  bool _feedRefreshing = false;
  bool _feedHasMore = true;
  int _feedPage = 0;
  String? _feedError;

  // Post detail state
  FeedPostDto? _selectedPost;
  bool _postLoading = false;

  // Comments state (keyed by post ID)
  final Map<int, List<CommentDto>> _postComments = {};
  final Map<int, bool> _commentsLoading = {};
  final Map<int, bool> _commentsHasMore = {};
  final Map<int, int> _commentsPage = {};

  // Action loading states
  bool _creatingPost = false;
  bool _deletingPost = false;
  bool _addingComment = false;

  FeedProvider({
    String baseUrl = 'http://35.158.35.102:8080',
    FeedRepository? repository,
  }) : _repository = repository ?? FeedRepository(baseUrl: baseUrl);

  // Getters
  List<FeedPostDto> get feedPosts => _feedPosts;
  bool get feedLoading => _feedLoading;
  bool get feedRefreshing => _feedRefreshing;
  bool get feedHasMore => _feedHasMore;
  String? get feedError => _feedError;

  FeedPostDto? get selectedPost => _selectedPost;
  bool get postLoading => _postLoading;

  bool get creatingPost => _creatingPost;
  bool get deletingPost => _deletingPost;
  bool get addingComment => _addingComment;

  /// Set authentication token
  void setAuthToken(String token) {
    _repository.setAuthToken(token);
  }

  /// Load feed (initial load or refresh)
  Future<void> loadFeed({bool refresh = false}) async {
    if (_feedLoading) return;

    if (refresh) {
      _feedPage = 0;
      _feedHasMore = true;
      _feedRefreshing = true;
    } else {
      _feedLoading = true;
    }
    _feedError = null;
    notifyListeners();

    final result = await _repository.getFeed(page: _feedPage);

    if (result.success && result.data != null) {
      if (refresh) {
        _feedPosts = result.data!.content;
      } else {
        _feedPosts = [..._feedPosts, ...result.data!.content];
      }
      _feedHasMore = !result.data!.last;
      _feedPage++;
    } else {
      _feedError = result.message;
    }

    _feedLoading = false;
    _feedRefreshing = false;
    notifyListeners();
  }

  /// Load more feed posts (pagination)
  Future<void> loadMoreFeed() async {
    if (!_feedHasMore || _feedLoading) return;
    await loadFeed();
  }

  /// Get comments for a post
  List<CommentDto> getCommentsForPost(int postId) {
    return _postComments[postId] ?? [];
  }

  /// Check if comments are loading for a post
  bool isCommentsLoading(int postId) {
    return _commentsLoading[postId] ?? false;
  }

  /// Check if there are more comments for a post
  bool hasMoreComments(int postId) {
    return _commentsHasMore[postId] ?? true;
  }

  /// Load a single post
  Future<FeedPostDto?> loadPost(int postId) async {
    _postLoading = true;
    notifyListeners();

    final result = await _repository.getPost(postId);

    _postLoading = false;
    if (result.success && result.data != null) {
      _selectedPost = result.data;
      notifyListeners();
      return result.data;
    }

    notifyListeners();
    return null;
  }

  /// Create a new post
  Future<FeedResult<FeedPostDto>> createPost(CreatePostDto request) async {
    _creatingPost = true;
    notifyListeners();

    final result = await _repository.createPost(request);

    if (result.success && result.data != null) {
      // Add new post to the beginning of the feed
      _feedPosts = [result.data!, ..._feedPosts];
    }

    _creatingPost = false;
    notifyListeners();

    return result;
  }

  /// Delete a post
  Future<FeedResult<void>> deletePost(int postId) async {
    _deletingPost = true;
    notifyListeners();

    final result = await _repository.deletePost(postId);

    if (result.success) {
      _feedPosts.removeWhere((p) => p.id == postId);
      _postComments.remove(postId);
    }

    _deletingPost = false;
    notifyListeners();

    return result;
  }

  /// Toggle like on a post (optimistic update)
  Future<void> toggleLike(int postId) async {
    // Find the post
    final index = _feedPosts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = _feedPosts[index];
    final isCurrentlyLiked = post.isLikedByCurrentUser;

    // Optimistic update
    _feedPosts[index] = post.copyWith(
      isLikedByCurrentUser: !isCurrentlyLiked,
      likesCount: isCurrentlyLiked ? post.likesCount - 1 : post.likesCount + 1,
    );
    notifyListeners();

    // Make API call
    final result = isCurrentlyLiked
        ? await _repository.unlikePost(postId)
        : await _repository.likePost(postId);

    // Revert on failure
    if (!result.success) {
      _feedPosts[index] = post;
      notifyListeners();
    }
  }

  /// Load comments for a post
  Future<void> loadComments(int postId, {bool refresh = false}) async {
    if (_commentsLoading[postId] == true) return;

    if (refresh) {
      _commentsPage[postId] = 0;
      _commentsHasMore[postId] = true;
    }

    _commentsLoading[postId] = true;
    notifyListeners();

    final page = _commentsPage[postId] ?? 0;
    final result = await _repository.getComments(postId, page: page);

    if (result.success && result.data != null) {
      if (refresh || _postComments[postId] == null) {
        _postComments[postId] = result.data!.content;
      } else {
        _postComments[postId] = [
          ..._postComments[postId]!,
          ...result.data!.content,
        ];
      }
      _commentsHasMore[postId] = !result.data!.last;
      _commentsPage[postId] = page + 1;
    }

    _commentsLoading[postId] = false;
    notifyListeners();
  }

  /// Load more comments for a post
  Future<void> loadMoreComments(int postId) async {
    if (_commentsHasMore[postId] != true || _commentsLoading[postId] == true) {
      return;
    }
    await loadComments(postId);
  }

  /// Add a comment to a post
  Future<FeedResult<CommentDto>> addComment(int postId, String text) async {
    _addingComment = true;
    notifyListeners();

    final result = await _repository.addComment(postId, text);

    if (result.success && result.data != null) {
      // Add new comment to the list
      _postComments[postId] = [
        result.data!,
        ...(_postComments[postId] ?? []),
      ];

      // Update comment count in the post
      final index = _feedPosts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        _feedPosts[index] = _feedPosts[index].copyWith(
          commentsCount: _feedPosts[index].commentsCount + 1,
        );
      }
    }

    _addingComment = false;
    notifyListeners();

    return result;
  }

  /// Delete a comment
  Future<FeedResult<void>> deleteComment(int postId, int commentId) async {
    final result = await _repository.deleteComment(postId, commentId);

    if (result.success) {
      _postComments[postId]?.removeWhere((c) => c.id == commentId);

      // Update comment count in the post
      final index = _feedPosts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        _feedPosts[index] = _feedPosts[index].copyWith(
          commentsCount: _feedPosts[index].commentsCount - 1,
        );
      }
      notifyListeners();
    }

    return result;
  }

  /// Clear selected post
  void clearSelectedPost() {
    _selectedPost = null;
    notifyListeners();
  }

  /// Clear all data (for logout)
  void clear() {
    _feedPosts = [];
    _feedLoading = false;
    _feedRefreshing = false;
    _feedHasMore = true;
    _feedPage = 0;
    _feedError = null;

    _selectedPost = null;
    _postLoading = false;

    _postComments.clear();
    _commentsLoading.clear();
    _commentsHasMore.clear();
    _commentsPage.clear();

    notifyListeners();
  }
}
