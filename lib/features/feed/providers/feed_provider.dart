import 'package:flutter/foundation.dart';
import '../data/feed_repository.dart';
import '../data/models/feed_post_dto.dart';
import '../data/models/comment_dto.dart';
import '../data/models/create_post_dto.dart';
import '../../profile/data/profile_repository.dart';
import '../../map/data/route_repository.dart';
import '../../run/data/run_repository.dart';

/// Provider for managing feed state
class FeedProvider extends ChangeNotifier {
  final FeedRepository _repository;
  final ProfileRepository _profileRepository;
  final RouteRepository _routeRepository;
  final RunRepository _runRepository;

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

  // Auth token for profile fetching
  String? _authToken;

  FeedProvider({
    String baseUrl = 'http://35.158.35.102:8080',
    FeedRepository? repository,
    ProfileRepository? profileRepository,
    RouteRepository? routeRepository,
    RunRepository? runRepository,
  }) : _repository = repository ?? FeedRepository(baseUrl: baseUrl),
       _profileRepository = profileRepository ?? ProfileRepository(),
       _routeRepository = routeRepository ?? RouteRepository(),
       _runRepository = runRepository ?? RunRepository();

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
    _authToken = token;
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
      // Enrich posts with author info, counts, and route data
      var enrichedPosts = await _enrichPostsWithAuthorInfo(
        result.data!.content,
      );
      enrichedPosts = await _enrichPostsWithCounts(enrichedPosts);
      enrichedPosts = await _enrichPostsWithRouteInfo(enrichedPosts);

      if (refresh) {
        _feedPosts = enrichedPosts;
      } else {
        _feedPosts = [..._feedPosts, ...enrichedPosts];
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

  /// Enrich posts with author information from profile repository
  Future<List<FeedPostDto>> _enrichPostsWithAuthorInfo(
    List<FeedPostDto> posts,
  ) async {
    if (_authToken == null) return posts;

    // Collect unique author IDs that need fetching
    final authorIdsToFetch = <String>{};
    for (final post in posts) {
      if (post.authorId.isNotEmpty && post.authorUsername == null) {
        authorIdsToFetch.add(post.authorId);
      }
    }

    if (authorIdsToFetch.isEmpty) return posts;

    // Fetch profiles for all unique authors
    final profileCache = <String, Map<String, dynamic>>{};
    for (final authorId in authorIdsToFetch) {
      try {
        final result = await _profileRepository.getProfile(
          authorId,
          accessToken: _authToken!,
        );
        if (result.success && result.profile != null) {
          final profile = result.profile!;
          // Use firstName as username fallback, or construct from name
          final displayName = profile.fullName.isNotEmpty
              ? profile.fullName
              : profile.firstName ?? profile.userId;
          profileCache[authorId] = {
            'username': displayName,
            'firstName': profile.firstName,
            'lastName': profile.lastName,
            'profilePic': profile.profilePic,
          };
        }
      } catch (e) {
        // Ignore errors for individual profile fetches
      }
    }

    // Enrich posts with fetched profile data
    return posts.map((post) {
      final authorData = profileCache[post.authorId];
      if (authorData != null && post.authorUsername == null) {
        return post.copyWith(
          authorUsername: authorData['username'],
          authorFirstName: authorData['firstName'],
          authorLastName: authorData['lastName'],
          authorProfilePic: authorData['profilePic'],
        );
      }
      return post;
    }).toList();
  }

  /// Enrich posts with like/comment counts from separate API endpoints
  Future<List<FeedPostDto>> _enrichPostsWithCounts(
    List<FeedPostDto> posts,
  ) async {
    final enrichedPosts = <FeedPostDto>[];

    // Fetch counts in parallel for all posts
    final futures = posts.map((post) async {
      try {
        // Fetch like and comment counts in parallel for each post
        final results = await Future.wait([
          _repository.getLikeCount(post.id),
          _repository.getCommentCount(post.id),
          _repository.checkIfLiked(post.id),
        ]);

        final likeCount = results[0].success
            ? (results[0].data as int? ?? 0)
            : post.likesCount;
        final commentCount = results[1].success
            ? (results[1].data as int? ?? 0)
            : post.commentsCount;
        final isLiked = results[2].success
            ? (results[2].data as bool? ?? false)
            : post.isLikedByCurrentUser;

        return post.copyWith(
          likesCount: likeCount,
          commentsCount: commentCount,
          isLikedByCurrentUser: isLiked,
        );
      } catch (e) {
        // Silently fail - use existing values
        return post;
      }
    }).toList();

    final results = await Future.wait(futures);
    enrichedPosts.addAll(results);

    return enrichedPosts;
  }

  /// Enrich posts with route/run coordinate data for map display
  Future<List<FeedPostDto>> _enrichPostsWithRouteInfo(
    List<FeedPostDto> posts,
  ) async {
    if (_authToken == null) {
      return posts;
    }

    final enrichedPosts = <FeedPostDto>[];

    for (final post in posts) {
      // Skip if post already has route points or isn't a route/run post
      if (post.routePoints != null && post.routePoints!.isNotEmpty) {
        enrichedPosts.add(post);
        continue;
      }

      // Check if post has route or run that needs coordinate data
      if (post.postType == PostType.route && post.routeId != null) {
        try {
          final routeResult = await _routeRepository.getRouteById(
            routeId: post.routeId!,
            accessToken: _authToken,
          );
          if (routeResult.success && routeResult.route != null) {
            final route = routeResult.route!;
            enrichedPosts.add(
              post.copyWith(
                startPointLat: route.startPointLat,
                startPointLon: route.startPointLon,
                endPointLat: route.endPointLat,
                endPointLon: route.endPointLon,
                routePoints: route.points
                    .map(
                      (p) => <String, double>{
                        'latitude': p.latitude,
                        'longitude': p.longitude,
                      },
                    )
                    .toList(),
                routeDistanceM: route.distanceM,
                routeDurationS: route.estimatedDurationS,
                routeTitle: route.title,
              ),
            );
            continue;
          }
        } catch (e) {
          // Silently fail - post will be added without enrichment
        }
      } else if (post.postType == PostType.run && post.runSessionId != null) {
        try {
          final runResult = await _runRepository.getRunSession(
            post.runSessionId!,
            accessToken: _authToken,
          );
          if (runResult.success && runResult.data != null) {
            final run = runResult.data!;
            if (run.points.isNotEmpty) {
              enrichedPosts.add(
                post.copyWith(
                  startPointLat: run.points.first.latitude,
                  startPointLon: run.points.first.longitude,
                  endPointLat: run.points.last.latitude,
                  endPointLon: run.points.last.longitude,
                  routePoints: run.points
                      .map(
                        (p) => <String, double>{
                          'latitude': p.latitude,
                          'longitude': p.longitude,
                        },
                      )
                      .toList(),
                  runDistanceM: run.totalDistanceM,
                  runDurationS: run.movingTimeS,
                  runPaceSecPerKm: run.avgPaceSecPerKm,
                ),
              );
              continue;
            }
          }
        } catch (e) {
          // Silently fail - post will be added without enrichment
        }
      }

      // Add post without enrichment if fetch failed
      enrichedPosts.add(post);
    }

    return enrichedPosts;
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
      // Enrich comments with author info
      final enrichedComments = await _enrichCommentsWithAuthorInfo(
        result.data!.content,
      );

      if (refresh || _postComments[postId] == null) {
        _postComments[postId] = enrichedComments;
      } else {
        _postComments[postId] = [
          ..._postComments[postId]!,
          ...enrichedComments,
        ];
      }
      _commentsHasMore[postId] = !result.data!.last;
      _commentsPage[postId] = page + 1;
    }

    _commentsLoading[postId] = false;
    notifyListeners();
  }

  /// Enrich comments with author information from profile repository
  Future<List<CommentDto>> _enrichCommentsWithAuthorInfo(
    List<CommentDto> comments,
  ) async {
    if (_authToken == null) return comments;

    // Collect unique user IDs that need fetching
    final userIdsToFetch = <String>{};
    for (final comment in comments) {
      if (comment.userId.isNotEmpty && comment.authorUsername == null) {
        userIdsToFetch.add(comment.userId);
      }
    }

    if (userIdsToFetch.isEmpty) return comments;

    // Fetch profiles for all unique users
    final profileCache = <String, Map<String, dynamic>>{};
    for (final userId in userIdsToFetch) {
      try {
        final result = await _profileRepository.getProfile(
          userId,
          accessToken: _authToken!,
        );
        if (result.success && result.profile != null) {
          final profile = result.profile!;
          final displayName = profile.fullName.isNotEmpty
              ? profile.fullName
              : profile.firstName ?? profile.userId;
          profileCache[userId] = {
            'username': displayName,
            'firstName': profile.firstName,
            'lastName': profile.lastName,
            'profilePic': profile.profilePic,
          };
        }
      } catch (e) {
        // Ignore errors for individual profile fetches
      }
    }

    // Enrich comments with fetched profile data
    return comments.map((comment) {
      final userData = profileCache[comment.userId];
      if (userData != null && comment.authorUsername == null) {
        return comment.copyWith(
          authorUsername: userData['username'],
          authorFirstName: userData['firstName'],
          authorLastName: userData['lastName'],
          authorProfilePic: userData['profilePic'],
        );
      }
      return comment;
    }).toList();
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
      _postComments[postId] = [result.data!, ...(_postComments[postId] ?? [])];

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
    final result = await _repository.deleteComment(commentId);

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

  /// Check if current user has liked a post
  Future<bool> checkIfLiked(int postId) async {
    final result = await _repository.checkIfLiked(postId);
    return result.success && result.data == true;
  }

  /// Get like count for a post
  Future<int> getLikeCount(int postId) async {
    final result = await _repository.getLikeCount(postId);
    return result.success ? (result.data ?? 0) : 0;
  }

  /// Get comment count for a post
  Future<int> getCommentCount(int postId) async {
    final result = await _repository.getCommentCount(postId);
    return result.success ? (result.data ?? 0) : 0;
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
